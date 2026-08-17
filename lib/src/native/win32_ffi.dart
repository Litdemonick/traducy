// Bindings Win32 mínimas hechas con dart:ffi directo.
//
// Se escriben a mano (en lugar de usar package:win32) porque esa librería
// cambia firmas y constantes entre versiones mayores; aquí los valores están
// fijados tal y como los define la API de Windows, así que actualizar
// dependencias no rompe la captura.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------- constantes

const int kNull = 0;

// BitBlt
const int srccopy = 0x00CC0020;
const int captureblt = 0x40000000;

// DIB
const int biRgb = 0;
const int dibRgbColors = 0;

// GetSystemMetrics
const int smCxScreen = 0;
const int smCyScreen = 1;
const int smXVirtualScreen = 76;
const int smYVirtualScreen = 77;
const int smCxVirtualScreen = 78;
const int smCyVirtualScreen = 79;

// Estilos extendidos de ventana
const int gwlExStyle = -20;
const int wsExLayered = 0x00080000;
const int wsExTransparent = 0x00000020;
const int wsExNoActivate = 0x08000000;

/// Fuerza la presencia en la barra de tareas.
///
/// Es obligatorio junto a `WS_EX_NOACTIVATE`: por sí solo, ese estilo saca la
/// ventana de la barra de tareas, y activarlo y desactivarlo hacía que el botón
/// apareciese y desapareciese solo.
const int wsExAppWindow = 0x00040000;
const int wsExToolWindow = 0x00000080;

// SetLayeredWindowAttributes
const int lwaColorKey = 0x00000001;
const int lwaAlpha = 0x00000002;

// SetWindowDisplayAffinity. WDA_EXCLUDEFROMCAPTURE necesita Win10 2004+ y es
// lo que evita que el overlay se vea a sí mismo en la captura.
const int wdaNone = 0x00000000;
const int wdaMonitor = 0x00000001;
const int wdaExcludeFromCapture = 0x00000011;

// SetWindowPos
const int hwndTopmost = -1;
const int swpNoSize = 0x0001;
const int swpNoMove = 0x0002;
const int swpNoActivate = 0x0010;
const int swpShowWindow = 0x0040;

// PrintWindow
const int pwRenderFullContent = 0x00000002;

// ------------------------------------------------------------------ structs

final class Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class BitmapInfoHeader extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

// ---------------------------------------------------------------- librerías

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final int Function() getCurrentProcessId = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetCurrentProcessId');

final int Function(int hWnd, Pointer<Uint32> processId)
getWindowThreadProcessId = _user32
    .lookupFunction<
      Uint32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetWindowThreadProcessId');

// ------------------------------------------------------------------- user32

final int Function(int hWnd) getDC = _user32
    .lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GetDC');

final int Function(int hWnd, int hDC) releaseDC = _user32
    .lookupFunction<Int32 Function(IntPtr, IntPtr), int Function(int, int)>(
      'ReleaseDC',
    );

final int Function(int index) getSystemMetrics = _user32
    .lookupFunction<Int32 Function(Int32), int Function(int)>(
      'GetSystemMetrics',
    );

final int Function(
  int hWndParent,
  int hWndChildAfter,
  Pointer<Utf16> className,
  Pointer<Utf16> windowName,
)
findWindowEx = _user32
    .lookupFunction<
      IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>),
      int Function(int, int, Pointer<Utf16>, Pointer<Utf16>)
    >('FindWindowExW');

final int Function(int hWnd, int index) getWindowLongPtr = _user32
    .lookupFunction<IntPtr Function(IntPtr, Int32), int Function(int, int)>(
      'GetWindowLongPtrW',
    );

final int Function(int hWnd, int index, int newLong) setWindowLongPtr = _user32
    .lookupFunction<
      IntPtr Function(IntPtr, Int32, IntPtr),
      int Function(int, int, int)
    >('SetWindowLongPtrW');

final int Function(int hWnd, int affinity) setWindowDisplayAffinity = _user32
    .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
      'SetWindowDisplayAffinity',
    );

final int Function(int hWnd, int colorKey, int alpha, int flags)
setLayeredWindowAttributes = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Uint32, Uint8, Uint32),
      int Function(int, int, int, int)
    >('SetLayeredWindowAttributes');

final int Function(
  int hWnd,
  int hWndInsertAfter,
  int x,
  int y,
  int cx,
  int cy,
  int flags,
)
setWindowPos = _user32
    .lookupFunction<
      Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)
    >('SetWindowPos');

/// Códigos de tecla virtual usados para saber si hay un botón del ratón pulsado.
const int vkLButton = 0x01;
const int vkRButton = 0x02;

final class Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final int Function(Pointer<Point> point) getCursorPos = _user32
    .lookupFunction<
      Int32 Function(Pointer<Point>),
      int Function(Pointer<Point>)
    >('GetCursorPos');

final int Function(int virtualKey) getAsyncKeyState = _user32
    .lookupFunction<Int16 Function(Int32), int Function(int)>(
      'GetAsyncKeyState',
    );

final int Function(int hWnd, Pointer<Rect> rect) getWindowRect = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Rect>),
      int Function(int, Pointer<Rect>)
    >('GetWindowRect');

final int Function(int hWnd) isWindowVisible = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'IsWindowVisible',
    );

final int Function(int hWnd) isWindow = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsWindow');

final int Function(int hWnd) isIconic = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsIconic');

final int Function(int hWnd, Pointer<Utf16> buffer, int maxCount)
getWindowText = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Int32),
      int Function(int, Pointer<Utf16>, int)
    >('GetWindowTextW');

final int Function(int hWnd, Pointer<Utf16> buffer, int maxCount) getClassName =
    _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Int32),
      int Function(int, Pointer<Utf16>, int)
    >('GetClassNameW');

final int Function() getForegroundWindow = _user32
    .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');

typedef EnumWindowsProcNative = Int32 Function(IntPtr hWnd, IntPtr lParam);

final int Function(
  Pointer<NativeFunction<EnumWindowsProcNative>> proc,
  int lParam,
)
enumWindows = _user32
    .lookupFunction<
      Int32 Function(Pointer<NativeFunction<EnumWindowsProcNative>>, IntPtr),
      int Function(Pointer<NativeFunction<EnumWindowsProcNative>>, int)
    >('EnumWindows');

final int Function(int hWnd, int hdcBlt, int flags) printWindow = _user32
    .lookupFunction<
      Int32 Function(IntPtr, IntPtr, Uint32),
      int Function(int, int, int)
    >('PrintWindow');

// -------------------------------------------------------------------- gdi32

final int Function(int hdc) createCompatibleDC = _gdi32
    .lookupFunction<IntPtr Function(IntPtr), int Function(int)>(
      'CreateCompatibleDC',
    );

final int Function(int hdc, int cx, int cy) createCompatibleBitmap = _gdi32
    .lookupFunction<
      IntPtr Function(IntPtr, Int32, Int32),
      int Function(int, int, int)
    >('CreateCompatibleBitmap');

final int Function(int hdc, int hObject) selectObject = _gdi32
    .lookupFunction<IntPtr Function(IntPtr, IntPtr), int Function(int, int)>(
      'SelectObject',
    );

final int Function(
  int hdcDest,
  int xDest,
  int yDest,
  int w,
  int h,
  int hdcSrc,
  int xSrc,
  int ySrc,
  int rop,
)
bitBlt = _gdi32
    .lookupFunction<
      Int32 Function(
        IntPtr,
        Int32,
        Int32,
        Int32,
        Int32,
        IntPtr,
        Int32,
        Int32,
        Uint32,
      ),
      int Function(int, int, int, int, int, int, int, int, int)
    >('BitBlt');

final int Function(
  int hdc,
  int hbm,
  int start,
  int lines,
  Pointer<Uint8> bits,
  Pointer<Uint8> bmi,
  int usage,
)
getDIBits = _gdi32
    .lookupFunction<
      Int32 Function(
        IntPtr,
        IntPtr,
        Uint32,
        Uint32,
        Pointer<Uint8>,
        Pointer<Uint8>,
        Uint32,
      ),
      int Function(int, int, int, int, Pointer<Uint8>, Pointer<Uint8>, int)
    >('GetDIBits');

final int Function(int hObject) deleteObject = _gdi32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('DeleteObject');

final int Function(int hdc) deleteDC = _gdi32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('DeleteDC');
