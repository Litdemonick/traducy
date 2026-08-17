#ifndef RUNNER_WINDOWS_OCR_H_
#define RUNNER_WINDOWS_OCR_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Motor de OCR del propio Windows (Windows.Media.Ocr), expuesto a Dart.
//
// Es la alternativa gratuita de verdad a Tesseract: viene con el sistema, no
// necesita clave ni internet, y reconoce con la calidad del OCR que usa Windows
// para sus propias funciones, que en japones, chino y coreano es notablemente
// mejor que Tesseract sobre capturas de pantalla.
//
// Vive en el runner y no en un paquete porque hace falta C++/WinRT: no hay forma
// de llamar a estas APIs desde Dart puro, ni con FFI, porque son objetos WinRT
// que requieren activacion por el sistema.
//
// El canal se llama `traducy/windows_ocr` y ofrece tres metodos:
//   - `languages`  -> List<String> con las etiquetas BCP-47 reconocibles
//   - `recognize`  -> Map con `text`, a partir de los bytes de un PNG
//   - `dispose`    -> libera el motor en cache
//
// El reconocimiento corre en un hilo aparte y la respuesta se devuelve al hilo
// de la plataforma con un mensaje de ventana. Hacerlo sincrono seria mas corto,
// pero bloquearia el hilo de la interfaz varias veces por segundo y eso se ve
// como tirones en el overlay, justo encima del juego.
void RegisterWindowsOcrChannel(flutter::BinaryMessenger* messenger, HWND host);

// Atiende el mensaje con el que un trabajo terminado vuelve al hilo de la
// plataforma. Devuelve true si el mensaje era para nosotros.
bool HandleWindowsOcrMessage(UINT message, WPARAM wparam, LPARAM lparam);

// Mensaje privado de la ventana del runner. WM_APP esta reservado para la
// aplicacion, asi que no puede chocar con nada de Windows ni de Flutter.
constexpr UINT kWindowsOcrDoneMessage = WM_APP + 0x51;

#endif  // RUNNER_WINDOWS_OCR_H_
