; Instalador de Traducy para Windows (Inno Setup 6).
;
; Compilar:
;   flutter build windows --release
;   iscc installer\traducy.iss
;
; El resultado queda en installer\salida\TraducySetup-<version>.exe, listo para
; pasarselo a alguien y que lo instale sin mas.
;
; La version NO se edita aqui a mano. Se cambia con:
;   python tools\set_version.py 1.0.0.bs
; que la deja sincronizada en pubspec.yaml, en la app y en este fichero.

#define MyAppName "Traducy"
; Version visible, admite sufijo de letras para revisiones pequenas (1.0.0.bs).
#define MyAppVersion "1.0.0.c"
; La misma version en cuatro numeros. Windows almacena la version del ejecutable
; asi, y un sufijo de letras no es un numero: de ahi que haya dos formas.
#define MyAppVersionNumeric "1.0.0.3"
#define MyAppPublisher "Litdemonick"
#define MyAppAuthor "Litdemonick"
#define MyAppUrl "https://github.com/Litdemonick/traducy"
#define MyAppReleasesUrl "https://github.com/Litdemonick/traducy/releases"
#define MyAppIssuesUrl "https://github.com/Litdemonick/traducy/issues"
#define MyAppExeName "traducy.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; El AppId identifica el producto entre versiones. **No cambiar nunca**: es lo
; que permite reconocer una instalacion previa y actualizarla en su sitio en
; lugar de dejar dos copias del programa en el equipo.
AppId={{8F3A6C24-5B7D-4E19-9C0A-2D6E4B8F1A73}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersionNumeric}
VersionInfoProductVersion={#MyAppVersionNumeric}
VersionInfoProductTextVersion={#MyAppVersion}
VersionInfoDescription=Traductor de pantalla en tiempo real
VersionInfoCompany={#MyAppPublisher}
VersionInfoCopyright={#MyAppAuthor}

; Enlaces del proyecto. Windows los muestra en "Aplicaciones instaladas" y el
; asistente los pone en su pagina final: quien recibe el .exe puede comprobar de
; donde sale y donde reportar un fallo sin tener que preguntar.
AppPublisherURL={#MyAppUrl}
AppSupportURL={#MyAppIssuesUrl}
AppUpdatesURL={#MyAppReleasesUrl}
AppContact={#MyAppUrl}
AppReadmeFile={#MyAppUrl}

; Carpeta propuesta. La pagina de destino queda habilitada a proposito: asi se
; puede instalar en otra unidad si el disco C: va justo.
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
AllowNoIcons=yes

; Sin administrador si se instala en la carpeta del usuario, con el si se elige
; Archivos de programa. Windows lo decide segun el destino.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Aspecto: icono y logo propios.
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
WizardStyle=modern
; Los tamanos son los que espera Inno: 164x314 el panel lateral y 55x55 la
; cabecera. Una imagen mas grande no se reduce, se recorta, y el logo sale
; cortado. Se listan tambien las variantes al doble y Inno elige segun el DPI.
WizardImageFile=wizard_large.bmp,wizard_large@2x.bmp
WizardSmallImageFile=wizard_small.bmp,wizard_small@2x.bmp
WizardImageStretch=no

; Cierra Traducy antes de sustituir los ficheros. Sin esto, actualizar sobre una
; instalacion en marcha falla con "fichero en uso" y deja la copia a medias.
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no

Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=salida
OutputBaseFilename=TraducySetup-{#MyAppVersion}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
spanish.LaunchAfter=Abrir Traducy al terminar
spanish.DesktopTask=Crear un acceso directo en el escritorio
spanish.AboutProject=Traducy lo desarrolla {#MyAppAuthor} y su codigo es publico.%n%nProyecto: {#MyAppUrl}%nVersiones: {#MyAppReleasesUrl}%nFallos y sugerencias: {#MyAppIssuesUrl}
spanish.AboutHeading=Sobre el proyecto
spanish.FinishedInfo=Traducy {#MyAppVersion}, de {#MyAppAuthor}.%nCodigo y novedades: {#MyAppUrl}
spanish.NeedsTesseract=Traducy usa Tesseract OCR para leer el texto de la pantalla.%n%nSi no lo tienes instalado, la propia aplicacion te lo dira al abrirla y te ofrecera instalarlo con un boton. Los idiomas (japones, chino, coreano...) tambien se descargan desde la app.
spanish.UpdatingFrom=Se ha detectado Traducy %1 instalado.%n%nSe actualizara a la version %2 en la misma carpeta. Tus ajustes y los idiomas descargados se conservan.
spanish.DowngradeWarning=Ya tienes instalada la version %1, que es mas reciente que la %2 que estas a punto de instalar.%n%nQuieres continuar de todas formas?
spanish.FreshInstall=Instalacion nueva de Traducy %1.
spanish.ReplaceInstall=Reemplazando Traducy %1 por la version %2. Se instalara en la misma carpeta y tus ajustes se conservan.
spanish.SameVersion=Reinstalando Traducy %1 sobre la misma version.
english.LaunchAfter=Open Traducy when finished
english.DesktopTask=Create a desktop shortcut
english.AboutProject=Traducy is developed by {#MyAppAuthor} and its source code is public.%n%nProject: {#MyAppUrl}%nReleases: {#MyAppReleasesUrl}%nBugs and ideas: {#MyAppIssuesUrl}
english.AboutHeading=About this project
english.FinishedInfo=Traducy {#MyAppVersion}, by {#MyAppAuthor}.%nSource code and news: {#MyAppUrl}
english.NeedsTesseract=Traducy uses Tesseract OCR to read text from the screen.%n%nIf it is not installed, the app will tell you when you open it and offer to install it with a button. Languages are downloaded from the app too.
english.UpdatingFrom=Traducy %1 was found on this computer.%n%nIt will be updated to version %2 in the same folder. Your settings and downloaded languages are kept.
english.DowngradeWarning=You already have version %1 installed, which is newer than %2.%n%nDo you want to continue anyway?
english.FreshInstall=Fresh installation of Traducy %1.
english.ReplaceInstall=Replacing Traducy %1 with version %2. It will be installed in the same folder and your settings are kept.
english.SameVersion=Reinstalling Traducy %1 over the same version.

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopTask}"; GroupDescription: "{cm:AdditionalIcons}"

[Dirs]
; Todo lo que genera Traducy vive junto al programa, en la carpeta que elija el
; usuario: ajustes, idiomas del OCR y descargas de actualizaciones.
;
; `users-modify` es imprescindible. Si alguien instala en Archivos de programa,
; Windows solo da lectura a los usuarios normales, y la aplicacion (que corre sin
; privilegios) no podria guardar nada. Concediendo escritura a esta subcarpeta
; durante la instalacion, funciona igual en C:\Program Files, en D:\Juegos o en
; un USB, sin pedir permisos de administrador cada vez que se abre.
Name: "{app}\datos"; Permissions: users-modify

[Files]
; La carpeta Release completa: el .exe, las DLL de Flutter, los plugins y data\
; con los assets. Hay que copiarla entera; el .exe suelto no arranca.
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchAfter}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Los datos viven dentro de la carpeta del programa, asi que se van con el.
; Incluye los ajustes, los idiomas del OCR descargados y los instaladores que
; haya bajado el actualizador.
Type: filesandordirs; Name: "{app}\datos"

[Code]
var
  PreviousVersion: String;

{ Lee la version ya instalada desde el registro de desinstalacion. Devuelve
  cadena vacia si es una instalacion nueva. }
function GetInstalledVersion(): String;
var
  Value: String;
  Key: String;
begin
  Result := '';
  Key := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';
  { Se prueban las vistas del registro por usuario y por equipo: la instalacion
    previa pudo hacerse de cualquiera de las dos formas. }
  if RegQueryStringValue(HKEY_CURRENT_USER, Key, 'DisplayVersion', Value) then
    Result := Value
  else if RegQueryStringValue(HKEY_LOCAL_MACHINE, Key, 'DisplayVersion', Value) then
    Result := Value
  else if RegQueryStringValue(HKEY_LOCAL_MACHINE_32, Key, 'DisplayVersion', Value) then
    Result := Value;
end;

{ Separa una version "1.2.3.bs" en sus tres numeros y el sufijo de letras.
  Se parsea a mano en lugar de usar funciones de division de cadenas para no
  depender de la version de Inno Setup instalada. }
procedure SplitVersion(Version: String; var A, B, C: Integer; var Suffix: String);
var
  I: Integer;
  Piece: String;
  Numbers: array[0..2] of Integer;
  Index: Integer;
begin
  Suffix := '';
  Numbers[0] := 0;
  Numbers[1] := 0;
  Numbers[2] := 0;

  { El sufijo son las letras minusculas del final. }
  I := Length(Version);
  while (I > 0) and (Version[I] >= 'a') and (Version[I] <= 'z') do
  begin
    Suffix := Version[I] + Suffix;
    I := I - 1;
  end;
  if (I > 0) and (Version[I] = '.') then
    Version := Copy(Version, 1, I - 1);

  Index := 0;
  Piece := '';
  for I := 1 to Length(Version) do
  begin
    if Version[I] = '.' then
    begin
      if Index <= 2 then
        Numbers[Index] := StrToIntDef(Piece, 0);
      Index := Index + 1;
      Piece := '';
    end
    else
      Piece := Piece + Version[I];
  end;
  if Index <= 2 then
    Numbers[Index] := StrToIntDef(Piece, 0);

  A := Numbers[0];
  B := Numbers[1];
  C := Numbers[2];
end;

{ Compara dos versiones del tipo 1.0.0.bs.
  Devuelve <0 si A es anterior, 0 si iguales, >0 si A es posterior.

  El sufijo se compara primero por longitud y luego alfabeticamente, que es el
  mismo orden que produce la numeracion tipo hoja de calculo: 'z' va antes de
  'aa' porque 'aa' es la revision 27. }
function CompareVersions(VersionA, VersionB: String): Integer;
var
  A1, A2, A3, B1, B2, B3: Integer;
  SuffixA, SuffixB: String;
begin
  SplitVersion(VersionA, A1, A2, A3, SuffixA);
  SplitVersion(VersionB, B1, B2, B3, SuffixB);

  if A1 <> B1 then
  begin
    Result := A1 - B1;
    Exit;
  end;
  if A2 <> B2 then
  begin
    Result := A2 - B2;
    Exit;
  end;
  if A3 <> B3 then
  begin
    Result := A3 - B3;
    Exit;
  end;

  if Length(SuffixA) <> Length(SuffixB) then
    Result := Length(SuffixA) - Length(SuffixB)
  else
    Result := CompareStr(SuffixA, SuffixB);
end;

function InitializeSetup(): Boolean;
var
  Message: String;
begin
  PreviousVersion := GetInstalledVersion();
  Result := True;

  if PreviousVersion = '' then
    Exit;

  if CompareVersions(PreviousVersion, '{#MyAppVersion}') > 0 then
  begin
    { Instalar una version anterior encima de una mas nueva casi nunca es lo que
      se quiere, asi que se avisa y se deja decidir. }
    Message := FmtMessage(ExpandConstant('{cm:DowngradeWarning}'), [PreviousVersion, '{#MyAppVersion}']);
    Result := MsgBox(Message, mbConfirmation, MB_YESNO) = IDYES;
  end;
end;

procedure InitializeWizard();
begin
  if PreviousVersion <> '' then
    WizardForm.WelcomeLabel2.Caption := FmtMessage(ExpandConstant('{cm:UpdatingFrom}'), [PreviousVersion, '{#MyAppVersion}']);

  { Autor y enlaces en la pagina final. Va aqui y no en un dialogo aparte para
    no anadir un paso mas al asistente: se lee de pasada al terminar. }
  WizardForm.FinishedLabel.Caption := WizardForm.FinishedLabel.Caption + #13#10 + #13#10 +
    ExpandConstant('{cm:FinishedInfo}');
end;

{ Resumen de lo que va a ocurrir, en la pagina de "listo para instalar". Se
  distingue instalacion nueva, reemplazo y reinstalacion de la misma version:
  quien recibe el .exe sabe asi si va a perder algo o no. }
function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  Summary: String;
  Comparison: Integer;
begin
  if PreviousVersion = '' then
    Summary := FmtMessage(ExpandConstant('{cm:FreshInstall}'), ['{#MyAppVersion}'])
  else
  begin
    Comparison := CompareVersions(PreviousVersion, '{#MyAppVersion}');
    if Comparison = 0 then
      Summary := FmtMessage(ExpandConstant('{cm:SameVersion}'), [PreviousVersion])
    else
      Summary := FmtMessage(ExpandConstant('{cm:ReplaceInstall}'), [PreviousVersion, '{#MyAppVersion}']);
  end;

  Result := Summary + NewLine + NewLine + MemoDirInfo;
  if MemoTasksInfo <> '' then
    Result := Result + NewLine + NewLine + MemoTasksInfo;
  Result := Result + NewLine + NewLine +
    ExpandConstant('{cm:AboutHeading}') + NewLine + Space +
    ExpandConstant('{cm:AboutProject}');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  { Aviso sobre Tesseract justo antes de copiar, para que nadie se lleve la
    sorpresa de que la app no traduce nada al abrirla. }
  if CurPageID = wpReady then
    MsgBox(ExpandConstant('{cm:NeedsTesseract}'), mbInformation, MB_OK);
  Result := True;
end;

