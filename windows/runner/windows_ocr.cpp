#include "windows_ocr.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>

#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResult;

// Un trabajo terminado, esperando volver al hilo de la plataforma.
struct FinishedJob {
  std::unique_ptr<MethodResult<EncodableValue>> result;
  bool ok = false;
  std::string text;
  std::string error_code;
  std::string error_message;
};

HWND g_host = nullptr;

// Motor en cache junto al idioma con el que se creo.
//
// Crear el motor cuesta bastante mas que reconocer, y el idioma cambia pocas
// veces, asi que rehacerlo en cada fotograma seria tirar tiempo a la basura.
std::mutex g_engine_mutex;
std::wstring g_engine_language;
winrt::Windows::Media::Ocr::OcrEngine g_engine{nullptr};

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return std::string();
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) return std::string();
  std::string out(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

std::wstring ToUtf16(const std::string& value) {
  if (value.empty()) return std::wstring();
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring out(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      out.data(), size);
  return out;
}

// Idiomas que el OCR del sistema puede reconocer ahora mismo.
//
// Dependen de los paquetes de idioma instalados en Windows, no de Traducy: si
// falta el japones, la interfaz tiene que poder decirlo y explicar como se
// anade, en lugar de fallar sin motivo aparente al reconocer.
std::vector<std::string> AvailableLanguages() {
  std::vector<std::string> out;
  try {
    for (const auto& language :
         winrt::Windows::Media::Ocr::OcrEngine::AvailableRecognizerLanguages()) {
      out.push_back(ToUtf8(std::wstring(language.LanguageTag())));
    }
  } catch (...) {
    // Sin WinRT disponible se devuelve una lista vacia y Dart lo interpreta
    // como "este motor no se puede usar aqui".
  }
  return out;
}

winrt::Windows::Media::Ocr::OcrEngine EngineFor(const std::wstring& tag) {
  std::lock_guard<std::mutex> guard(g_engine_mutex);
  if (g_engine != nullptr && g_engine_language == tag) return g_engine;

  winrt::Windows::Media::Ocr::OcrEngine engine{nullptr};
  if (tag.empty()) {
    // Sin idioma pedido se usa el del usuario: es lo que acierta mas a menudo
    // cuando no hay una preferencia explicita.
    engine =
        winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromUserProfileLanguages();
  } else {
    engine = winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(
        winrt::Windows::Globalization::Language(winrt::hstring(tag)));
  }
  if (engine != nullptr) {
    g_engine = engine;
    g_engine_language = tag;
  }
  return engine;
}

// Reconoce un PNG. Corre en un hilo de trabajo.
void Recognize(std::vector<uint8_t> png, std::wstring language,
               FinishedJob* job) {
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
  } catch (...) {
    // Ya inicializado en este hilo: no es un problema.
  }

  try {
    auto engine = EngineFor(language);
    if (engine == nullptr) {
      job->error_code = "sin_idioma";
      job->error_message =
          "El OCR de Windows no tiene ese idioma instalado.";
      return;
    }

    using namespace winrt::Windows::Storage::Streams;
    InMemoryRandomAccessStream stream;
    DataWriter writer(stream);
    writer.WriteBytes(winrt::array_view<const uint8_t>(png));
    writer.StoreAsync().get();
    writer.FlushAsync().get();
    writer.DetachStream();
    stream.Seek(0);

    auto decoder =
        winrt::Windows::Graphics::Imaging::BitmapDecoder::CreateAsync(stream)
            .get();
    auto bitmap = decoder.GetSoftwareBitmapAsync().get();

    // El OCR del sistema tiene un limite de tamano por lado. Si la imagen se
    // pasa, se reduce en lugar de fallar: es preferible perder algo de detalle
    // a no reconocer nada.
    const uint32_t limit =
        winrt::Windows::Media::Ocr::OcrEngine::MaxImageDimension();
    if (bitmap.PixelWidth() > static_cast<int32_t>(limit) ||
        bitmap.PixelHeight() > static_cast<int32_t>(limit)) {
      const double scale =
          static_cast<double>(limit) /
          static_cast<double>((std::max)(bitmap.PixelWidth(),
                                         bitmap.PixelHeight()));
      winrt::Windows::Graphics::Imaging::BitmapTransform transform;
      transform.ScaledWidth(
          static_cast<uint32_t>(bitmap.PixelWidth() * scale));
      transform.ScaledHeight(
          static_cast<uint32_t>(bitmap.PixelHeight() * scale));
      auto scaled =
          decoder
              .GetSoftwareBitmapAsync(
                  winrt::Windows::Graphics::Imaging::BitmapPixelFormat::Bgra8,
                  winrt::Windows::Graphics::Imaging::BitmapAlphaMode::Premultiplied,
                  transform,
                  winrt::Windows::Graphics::Imaging::ExifOrientationMode::
                      IgnoreExifOrientation,
                  winrt::Windows::Graphics::Imaging::ColorManagementMode::
                      DoNotColorManage)
              .get();
      bitmap = scaled;
    }

    auto ocr = engine.RecognizeAsync(bitmap).get();

    // Se devuelve linea a linea, no el texto plano de `Text()`: el motor junta
    // todo en un parrafo y se pierde la estructura del dialogo, que es lo que
    // permite luego unir o separar frases con criterio.
    std::wstring text;
    for (const auto& line : ocr.Lines()) {
      if (!text.empty()) text.push_back(L'\n');
      text.append(std::wstring(line.Text()));
    }

    job->text = ToUtf8(text);
    job->ok = true;
  } catch (const winrt::hresult_error& error) {
    job->error_code = "ocr_windows";
    job->error_message = ToUtf8(std::wstring(error.message()));
  } catch (...) {
    job->error_code = "ocr_windows";
    job->error_message = "Fallo inesperado en el OCR de Windows.";
  }
}

void HandleCall(const MethodCall<EncodableValue>& call,
                std::unique_ptr<MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "languages") {
    EncodableList list;
    for (const auto& tag : AvailableLanguages()) {
      list.push_back(EncodableValue(tag));
    }
    result->Success(EncodableValue(list));
    return;
  }

  if (method == "dispose") {
    std::lock_guard<std::mutex> guard(g_engine_mutex);
    g_engine = nullptr;
    g_engine_language.clear();
    result->Success();
    return;
  }

  if (method != "recognize") {
    result->NotImplemented();
    return;
  }

  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("argumentos", "Faltan los argumentos.");
    return;
  }

  std::vector<uint8_t> png;
  std::wstring language;
  for (const auto& entry : *arguments) {
    const auto* key = std::get_if<std::string>(&entry.first);
    if (key == nullptr) continue;
    if (*key == "png") {
      if (const auto* bytes = std::get_if<std::vector<uint8_t>>(&entry.second)) {
        png = *bytes;
      }
    } else if (*key == "language") {
      if (const auto* tag = std::get_if<std::string>(&entry.second)) {
        language = ToUtf16(*tag);
      }
    }
  }

  if (png.empty()) {
    result->Error("imagen", "La imagen llego vacia.");
    return;
  }

  auto* job = new FinishedJob();
  job->result = std::move(result);

  // Un hilo por peticion. El pipeline solo tiene un ciclo activo a la vez, asi
  // que nunca hay mas de uno o dos vivos, y un pool para eso seria mas codigo
  // que beneficio.
  std::thread([png = std::move(png), language = std::move(language),
               job]() mutable {
    Recognize(std::move(png), std::move(language), job);
    if (g_host == nullptr ||
        !PostMessage(g_host, kWindowsOcrDoneMessage, 0,
                     reinterpret_cast<LPARAM>(job))) {
      // Sin ventana a la que volver, se responde desde aqui. No es lo correcto
      // en el modelo de Flutter, pero pasa solo durante el cierre y es mejor
      // que dejar la llamada de Dart esperando para siempre.
      delete job;
    }
  }).detach();
}

}  // namespace

void RegisterWindowsOcrChannel(flutter::BinaryMessenger* messenger, HWND host) {
  g_host = host;
  static std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "traducy/windows_ocr",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const MethodCall<EncodableValue>& call,
         std::unique_ptr<MethodResult<EncodableValue>> result) {
        HandleCall(call, std::move(result));
      });
}

bool HandleWindowsOcrMessage(UINT message, WPARAM, LPARAM lparam) {
  if (message != kWindowsOcrDoneMessage) return false;

  auto* job = reinterpret_cast<FinishedJob*>(lparam);
  if (job == nullptr) return true;

  if (job->ok) {
    EncodableMap payload;
    payload[EncodableValue("text")] = EncodableValue(job->text);
    job->result->Success(EncodableValue(payload));
  } else {
    job->result->Error(job->error_code, job->error_message);
  }
  delete job;
  return true;
}
