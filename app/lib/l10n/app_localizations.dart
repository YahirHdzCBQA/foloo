import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'ES'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'EN'**
  String get languageEnglish;

  /// No description provided for @loginUser.
  ///
  /// In es, this message translates to:
  /// **'USUARIO'**
  String get loginUser;

  /// No description provided for @loginPassword.
  ///
  /// In es, this message translates to:
  /// **'CONTRASEÑA'**
  String get loginPassword;

  /// No description provided for @loginEnter.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get loginEnter;

  /// No description provided for @loginUserRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu usuario'**
  String get loginUserRequired;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu contraseña'**
  String get loginPasswordRequired;

  /// No description provided for @authenticationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión. Revisa tus datos e intenta otra vez.'**
  String get authenticationFailed;

  /// No description provided for @loginShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get loginHidePassword;

  /// No description provided for @demoPlan.
  ///
  /// In es, this message translates to:
  /// **'PLAN DEMO'**
  String get demoPlan;

  /// No description provided for @demoPlanHelp.
  ///
  /// In es, this message translates to:
  /// **'Selector temporal para desarrollo y QA.'**
  String get demoPlanHelp;

  /// No description provided for @drawerClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar menú'**
  String get drawerClose;

  /// No description provided for @drawerHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get drawerHome;

  /// No description provided for @drawerHere.
  ///
  /// In es, this message translates to:
  /// **'AQUÍ'**
  String get drawerHere;

  /// No description provided for @drawerContent.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get drawerContent;

  /// No description provided for @drawerEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get drawerEmail;

  /// No description provided for @drawerRecords.
  ///
  /// In es, this message translates to:
  /// **'Registros'**
  String get drawerRecords;

  /// No description provided for @drawerEvents.
  ///
  /// In es, this message translates to:
  /// **'Mis eventos'**
  String get drawerEvents;

  /// No description provided for @drawerAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get drawerAppearance;

  /// No description provided for @drawerDarkMode.
  ///
  /// In es, this message translates to:
  /// **'MODO OSCURO'**
  String get drawerDarkMode;

  /// No description provided for @drawerLightMode.
  ///
  /// In es, this message translates to:
  /// **'MODO CLARO'**
  String get drawerLightMode;

  /// No description provided for @drawerAppearanceSemantics.
  ///
  /// In es, this message translates to:
  /// **'Apariencia, modo oscuro'**
  String get drawerAppearanceSemantics;

  /// No description provided for @drawerLogout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get drawerLogout;

  /// No description provided for @drawerSales.
  ///
  /// In es, this message translates to:
  /// **'VENTAS'**
  String get drawerSales;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @openMenu.
  ///
  /// In es, this message translates to:
  /// **'Abrir menú'**
  String get openMenu;

  /// No description provided for @offline.
  ///
  /// In es, this message translates to:
  /// **'SIN CONEXIÓN'**
  String get offline;

  /// No description provided for @online.
  ///
  /// In es, this message translates to:
  /// **'EN LÍNEA'**
  String get online;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Antes de\ntu primer lead'**
  String get profileTitle;

  /// No description provided for @profileHelp.
  ///
  /// In es, this message translates to:
  /// **'Esto va en cada lead que captures. Se guarda en tu teléfono.'**
  String get profileHelp;

  /// No description provided for @profilePhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil'**
  String get profilePhoto;

  /// No description provided for @profileTakePhoto.
  ///
  /// In es, this message translates to:
  /// **'Tomar foto'**
  String get profileTakePhoto;

  /// No description provided for @profileGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de galería'**
  String get profileGallery;

  /// No description provided for @profileFullName.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get profileFullName;

  /// No description provided for @company.
  ///
  /// In es, this message translates to:
  /// **'Empresa'**
  String get company;

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueAction;

  /// No description provided for @originTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde estás\nconectando hoy?'**
  String get originTitle;

  /// No description provided for @leadSource.
  ///
  /// In es, this message translates to:
  /// **'Origen del lead'**
  String get leadSource;

  /// No description provided for @event.
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get event;

  /// No description provided for @directLead.
  ///
  /// In es, this message translates to:
  /// **'Lead directo'**
  String get directLead;

  /// No description provided for @directLeadHelp.
  ///
  /// In es, this message translates to:
  /// **'Se guarda sin evento, en tu base general de leads.'**
  String get directLeadHelp;

  /// No description provided for @place.
  ///
  /// In es, this message translates to:
  /// **'Lugar'**
  String get place;

  /// No description provided for @createNewEvent.
  ///
  /// In es, this message translates to:
  /// **'Crear evento nuevo'**
  String get createNewEvent;

  /// No description provided for @captureConnection.
  ///
  /// In es, this message translates to:
  /// **'Capturar conexión'**
  String get captureConnection;

  /// No description provided for @startCapture.
  ///
  /// In es, this message translates to:
  /// **'Empezar a capturar'**
  String get startCapture;

  /// No description provided for @cardSection.
  ///
  /// In es, this message translates to:
  /// **'La tarjeta'**
  String get cardSection;

  /// No description provided for @noCardPhoto.
  ///
  /// In es, this message translates to:
  /// **'Sin foto aún'**
  String get noCardPhoto;

  /// No description provided for @chooseGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de galería'**
  String get chooseGallery;

  /// No description provided for @changePhoto.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto'**
  String get changePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In es, this message translates to:
  /// **'Tomar foto'**
  String get takePhoto;

  /// No description provided for @remove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get remove;

  /// No description provided for @reprocess.
  ///
  /// In es, this message translates to:
  /// **'Reprocesar'**
  String get reprocess;

  /// No description provided for @leadData.
  ///
  /// In es, this message translates to:
  /// **'Datos del lead'**
  String get leadData;

  /// No description provided for @clear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;

  /// No description provided for @firstName.
  ///
  /// In es, this message translates to:
  /// **'NOMBRE'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In es, this message translates to:
  /// **'APELLIDO'**
  String get lastName;

  /// No description provided for @role.
  ///
  /// In es, this message translates to:
  /// **'PUESTO'**
  String get role;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'CORREO'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In es, this message translates to:
  /// **'TELÉFONO'**
  String get phone;

  /// No description provided for @leadType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de Lead'**
  String get leadType;

  /// No description provided for @supplier.
  ///
  /// In es, this message translates to:
  /// **'Proveedor'**
  String get supplier;

  /// No description provided for @partner.
  ///
  /// In es, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @client.
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get client;

  /// No description provided for @interestLevel.
  ///
  /// In es, this message translates to:
  /// **'NIVEL DE INTERÉS'**
  String get interestLevel;

  /// No description provided for @interestLow.
  ///
  /// In es, this message translates to:
  /// **'Bajo'**
  String get interestLow;

  /// No description provided for @interestMedium.
  ///
  /// In es, this message translates to:
  /// **'Medio'**
  String get interestMedium;

  /// No description provided for @interestHigh.
  ///
  /// In es, this message translates to:
  /// **'Alto'**
  String get interestHigh;

  /// No description provided for @conversationNote.
  ///
  /// In es, this message translates to:
  /// **'Nota de la plática'**
  String get conversationNote;

  /// No description provided for @voiceNoteOptional.
  ///
  /// In es, this message translates to:
  /// **'Nota de voz (opcional)'**
  String get voiceNoteOptional;

  /// No description provided for @recording.
  ///
  /// In es, this message translates to:
  /// **'GRABANDO'**
  String get recording;

  /// No description provided for @deleteAudio.
  ///
  /// In es, this message translates to:
  /// **'Borrar audio'**
  String get deleteAudio;

  /// No description provided for @recordAgain.
  ///
  /// In es, this message translates to:
  /// **'Volver a grabar'**
  String get recordAgain;

  /// No description provided for @playAudio.
  ///
  /// In es, this message translates to:
  /// **'Reproducir audio'**
  String get playAudio;

  /// No description provided for @pauseAudio.
  ///
  /// In es, this message translates to:
  /// **'Pausar audio'**
  String get pauseAudio;

  /// No description provided for @stopRecording.
  ///
  /// In es, this message translates to:
  /// **'Detener grabación'**
  String get stopRecording;

  /// No description provided for @startRecording.
  ///
  /// In es, this message translates to:
  /// **'Iniciar grabación'**
  String get startRecording;

  /// No description provided for @writtenNote.
  ///
  /// In es, this message translates to:
  /// **'Nota escrita'**
  String get writtenNote;

  /// No description provided for @writtenNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe aquí lo importante de la conversación.'**
  String get writtenNoteHint;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @savePro.
  ///
  /// In es, this message translates to:
  /// **'Guarda y da “foloo”'**
  String get savePro;

  /// No description provided for @recordsTitle.
  ///
  /// In es, this message translates to:
  /// **'Registros'**
  String get recordsTitle;

  /// No description provided for @searchRecords.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o empresa'**
  String get searchRecords;

  /// No description provided for @all.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get all;

  /// No description provided for @clients.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get clients;

  /// No description provided for @partners.
  ///
  /// In es, this message translates to:
  /// **'Partners'**
  String get partners;

  /// No description provided for @suppliers.
  ///
  /// In es, this message translates to:
  /// **'Proveedores'**
  String get suppliers;

  /// No description provided for @export.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get export;

  /// No description provided for @sync.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar'**
  String get sync;

  /// No description provided for @exportRecords.
  ///
  /// In es, this message translates to:
  /// **'Exportar registros'**
  String get exportRecords;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @contentTitle.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get contentTitle;

  /// No description provided for @uploadPdf.
  ///
  /// In es, this message translates to:
  /// **'Subir PDF'**
  String get uploadPdf;

  /// No description provided for @noFiles.
  ///
  /// In es, this message translates to:
  /// **'Sin archivos'**
  String get noFiles;

  /// No description provided for @emptyContentTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin contenido todavía'**
  String get emptyContentTitle;

  /// No description provided for @emptyContentHelp.
  ///
  /// In es, this message translates to:
  /// **'Toca “Subir PDF” y elige el archivo de tu teléfono. Vive en la app y luego eliges a qué eventos aplica.'**
  String get emptyContentHelp;

  /// No description provided for @pdfSelectionError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el PDF. Elige un archivo PDF e inténtalo de nuevo.'**
  String get pdfSelectionError;

  /// No description provided for @emailTitle.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get emailTitle;

  /// No description provided for @subject.
  ///
  /// In es, this message translates to:
  /// **'Asunto'**
  String get subject;

  /// No description provided for @body.
  ///
  /// In es, this message translates to:
  /// **'Cuerpo'**
  String get body;

  /// No description provided for @variables.
  ///
  /// In es, this message translates to:
  /// **'Variables'**
  String get variables;

  /// No description provided for @preview.
  ///
  /// In es, this message translates to:
  /// **'Previsualización'**
  String get preview;

  /// No description provided for @saveTemplate.
  ///
  /// In es, this message translates to:
  /// **'Guardar plantilla'**
  String get saveTemplate;

  /// No description provided for @eventsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis eventos'**
  String get eventsTitle;

  /// No description provided for @createEvent.
  ///
  /// In es, this message translates to:
  /// **'Crear evento'**
  String get createEvent;

  /// No description provided for @createAction.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get createAction;

  /// No description provided for @deleteEvent.
  ///
  /// In es, this message translates to:
  /// **'Eliminar evento'**
  String get deleteEvent;

  /// No description provided for @saveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get saveChanges;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Regresar'**
  String get back;

  /// No description provided for @starts.
  ///
  /// In es, this message translates to:
  /// **'Inicia'**
  String get starts;

  /// No description provided for @ends.
  ///
  /// In es, this message translates to:
  /// **'Termina'**
  String get ends;

  /// No description provided for @pendingUpload.
  ///
  /// In es, this message translates to:
  /// **'por subir'**
  String get pendingUpload;

  /// No description provided for @reviewFields.
  ///
  /// In es, this message translates to:
  /// **'Revisa los campos marcados antes de continuar.'**
  String get reviewFields;

  /// No description provided for @cancelAndDelete.
  ///
  /// In es, this message translates to:
  /// **'CANCELAR Y BORRAR'**
  String get cancelAndDelete;

  /// No description provided for @displayName.
  ///
  /// In es, this message translates to:
  /// **'Nombre para mostrar'**
  String get displayName;

  /// No description provided for @searchEvents.
  ///
  /// In es, this message translates to:
  /// **'Buscar entre eventos'**
  String get searchEvents;

  /// No description provided for @allEvents.
  ///
  /// In es, this message translates to:
  /// **'Todos los eventos'**
  String get allEvents;

  /// No description provided for @allEventsHelp.
  ///
  /// In es, this message translates to:
  /// **'Ignora la selección de abajo'**
  String get allEventsHelp;

  /// No description provided for @upload.
  ///
  /// In es, this message translates to:
  /// **'Subir'**
  String get upload;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @deleteFile.
  ///
  /// In es, this message translates to:
  /// **'Eliminar archivo'**
  String get deleteFile;

  /// No description provided for @filesSummary.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 archivos} =1{1 archivo} other{{count} archivos}} · 4.9 MB'**
  String filesSummary(num count);

  /// No description provided for @fileCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 archivos} =1{1 archivo} other{{count} archivos}}'**
  String fileCount(num count);

  /// No description provided for @templateSavedDemo.
  ///
  /// In es, this message translates to:
  /// **'Plantilla guardada solo en esta demo.'**
  String get templateSavedDemo;

  /// No description provided for @audioPlaybackError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reproducir esta nota local.'**
  String get audioPlaybackError;

  /// No description provided for @xlsHelp.
  ///
  /// In es, this message translates to:
  /// **'Hoja de Excel, listo para abrir'**
  String get xlsHelp;

  /// No description provided for @csvHelp.
  ///
  /// In es, this message translates to:
  /// **'Texto plano, para otro sistema'**
  String get csvHelp;

  /// No description provided for @interest.
  ///
  /// In es, this message translates to:
  /// **'Interés {level}'**
  String interest(Object level);

  /// No description provided for @contactEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get contactEmail;

  /// No description provided for @contactPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get contactPhone;

  /// No description provided for @contactRole.
  ///
  /// In es, this message translates to:
  /// **'Puesto'**
  String get contactRole;

  /// No description provided for @frozenAttachment.
  ///
  /// In es, this message translates to:
  /// **'Adjunto congelado al guardar'**
  String get frozenAttachment;

  /// No description provided for @leadEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo al lead'**
  String get leadEmail;

  /// No description provided for @adminCopy.
  ///
  /// In es, this message translates to:
  /// **'Copia Admin'**
  String get adminCopy;

  /// No description provided for @progressCard.
  ///
  /// In es, this message translates to:
  /// **'01 Tarjeta'**
  String get progressCard;

  /// No description provided for @progressData.
  ///
  /// In es, this message translates to:
  /// **'02 Datos'**
  String get progressData;

  /// No description provided for @progressType.
  ///
  /// In es, this message translates to:
  /// **'03 Tipo'**
  String get progressType;

  /// No description provided for @progressNote.
  ///
  /// In es, this message translates to:
  /// **'04 Nota'**
  String get progressNote;

  /// No description provided for @imageOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la imagen. Puedes continuar sin foto.'**
  String get imageOpenError;

  /// No description provided for @nameRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu nombre'**
  String get nameRequired;

  /// No description provided for @companyRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu empresa'**
  String get companyRequired;

  /// No description provided for @eventName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del evento'**
  String get eventName;

  /// No description provided for @contentForEvent.
  ///
  /// In es, this message translates to:
  /// **'Contenido para este evento'**
  String get contentForEvent;

  /// No description provided for @contentAssignmentHelp.
  ///
  /// In es, this message translates to:
  /// **'Puedes asignarlo ahora o más tarde. Sin contenido el correo demo sale igual, solo sin adjuntos.'**
  String get contentAssignmentHelp;

  /// No description provided for @localFilesHelp.
  ///
  /// In es, this message translates to:
  /// **'Los archivos viven en tu teléfono y se adjuntan al correo cuando hay señal.'**
  String get localFilesHelp;

  /// No description provided for @emptyRecords.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay registros'**
  String get emptyRecords;

  /// No description provided for @emptyRecordsHelp.
  ///
  /// In es, this message translates to:
  /// **'Las conexiones guardadas aparecerán aquí.'**
  String get emptyRecordsHelp;

  /// No description provided for @voiceNote.
  ///
  /// In es, this message translates to:
  /// **'Nota de voz'**
  String get voiceNote;

  /// No description provided for @processingDemo.
  ///
  /// In es, this message translates to:
  /// **'Procesando · demo'**
  String get processingDemo;

  /// No description provided for @voiceUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible · no hay nota de voz'**
  String get voiceUnavailable;

  /// No description provided for @sentContentDemo.
  ///
  /// In es, this message translates to:
  /// **'Contenido enviado · demo'**
  String get sentContentDemo;

  /// No description provided for @emailStatusDemo.
  ///
  /// In es, this message translates to:
  /// **'Estado de correo · demo'**
  String get emailStatusDemo;

  /// No description provided for @queued.
  ///
  /// In es, this message translates to:
  /// **'En cola'**
  String get queued;

  /// No description provided for @sentDemo.
  ///
  /// In es, this message translates to:
  /// **'Enviado · demo'**
  String get sentDemo;

  /// No description provided for @editFileEvents.
  ///
  /// In es, this message translates to:
  /// **'Editar eventos del archivo'**
  String get editFileEvents;

  /// No description provided for @uploadContent.
  ///
  /// In es, this message translates to:
  /// **'Subir contenido'**
  String get uploadContent;

  /// No description provided for @emptyEvents.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes eventos'**
  String get emptyEvents;

  /// No description provided for @editEvent.
  ///
  /// In es, this message translates to:
  /// **'Editar evento'**
  String get editEvent;

  /// No description provided for @thisEvent.
  ///
  /// In es, this message translates to:
  /// **'Este evento'**
  String get thisEvent;

  /// No description provided for @eventTemplate.
  ///
  /// In es, this message translates to:
  /// **'Plantilla de seguimiento'**
  String get eventTemplate;

  /// No description provided for @directTemplate.
  ///
  /// In es, this message translates to:
  /// **'Plantilla para leads directos'**
  String get directTemplate;

  /// No description provided for @contentToShare.
  ///
  /// In es, this message translates to:
  /// **'Contenido a compartir'**
  String get contentToShare;

  /// No description provided for @offlineSaveHelp.
  ///
  /// In es, this message translates to:
  /// **'Se guarda en tu teléfono. Se sube cuando haya señal.'**
  String get offlineSaveHelp;

  /// No description provided for @transcriptionPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente. Aparecerá después de guardar la nota de voz.'**
  String get transcriptionPending;

  /// No description provided for @cardOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la imagen. Puedes continuar capturando los datos a mano.'**
  String get cardOpenError;

  /// No description provided for @cardReadSuccess.
  ///
  /// In es, this message translates to:
  /// **'Lectura demo completada. Revisa los datos.'**
  String get cardReadSuccess;

  /// No description provided for @cardReading.
  ///
  /// In es, this message translates to:
  /// **'Leyendo tarjeta…'**
  String get cardReading;

  /// No description provided for @cardReadIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Lectura demo completada. Completa los datos faltantes manualmente.'**
  String get cardReadIncomplete;

  /// No description provided for @cardReadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la tarjeta. Puedes continuar manualmente.'**
  String get cardReadError;

  /// No description provided for @microphoneDenied.
  ///
  /// In es, this message translates to:
  /// **'Permiso de micrófono rechazado. Puedes continuar con la nota escrita.'**
  String get microphoneDenied;

  /// No description provided for @recordStartError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la grabación. Puedes continuar con la nota escrita.'**
  String get recordStartError;

  /// No description provided for @recordKeepError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conservar la grabación. La nota escrita sigue disponible.'**
  String get recordKeepError;

  /// No description provided for @voiceSaved.
  ///
  /// In es, this message translates to:
  /// **'Nota de voz guardada localmente.'**
  String get voiceSaved;

  /// No description provided for @recordStopError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo terminar la grabación. Puedes continuar con la nota escrita.'**
  String get recordStopError;

  /// No description provided for @audioPlayError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reproducir el audio. Puedes borrarlo o volver a grabar.'**
  String get audioPlayError;

  /// No description provided for @audioPauseError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo pausar el audio. Puedes reproducirlo de nuevo.'**
  String get audioPauseError;

  /// No description provided for @audioDeleted.
  ///
  /// In es, this message translates to:
  /// **'Audio borrado. Puedes volver a grabar.'**
  String get audioDeleted;

  /// No description provided for @audioDeleteError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo borrar el audio. Inténtalo nuevamente.'**
  String get audioDeleteError;

  /// No description provided for @emailOrPhoneRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe correo o teléfono'**
  String get emailOrPhoneRequired;

  /// No description provided for @phoneOrEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe teléfono o correo'**
  String get phoneOrEmailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Revisa el formato del correo'**
  String get invalidEmail;

  /// No description provided for @leadNameRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio'**
  String get leadNameRequired;

  /// No description provided for @leadCompanyRequired.
  ///
  /// In es, this message translates to:
  /// **'La empresa es obligatoria'**
  String get leadCompanyRequired;

  /// No description provided for @placeRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe dónde surgió la conversación'**
  String get placeRequired;

  /// No description provided for @directPlaceHelp.
  ///
  /// In es, this message translates to:
  /// **'Dónde surgió la conversación. Sustituye {lugar} en el correo demo.'**
  String directPlaceHelp(Object lugar);

  /// No description provided for @savedLead.
  ///
  /// In es, this message translates to:
  /// **'Lead guardado'**
  String get savedLead;

  /// No description provided for @localSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar en el dispositivo. Revisa el espacio disponible e inténtalo de nuevo.'**
  String get localSaveError;

  /// No description provided for @mediaSaveWarning.
  ///
  /// In es, this message translates to:
  /// **'El lead quedó guardado, pero una foto o nota de voz opcional no pudo conservarse.'**
  String get mediaSaveWarning;

  /// No description provided for @captureAnother.
  ///
  /// In es, this message translates to:
  /// **'Capturar otro ahora'**
  String get captureAnother;

  /// No description provided for @dateAndTime.
  ///
  /// In es, this message translates to:
  /// **'Fecha y hora'**
  String get dateAndTime;

  /// No description provided for @origin.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get origin;

  /// No description provided for @capturedBy.
  ///
  /// In es, this message translates to:
  /// **'Capturó'**
  String get capturedBy;

  /// No description provided for @eventSpreadsheet.
  ///
  /// In es, this message translates to:
  /// **'En la hoja de cálculo del evento'**
  String get eventSpreadsheet;

  /// No description provided for @demoRow.
  ///
  /// In es, this message translates to:
  /// **'Fila demo · {folio}'**
  String demoRow(Object folio);

  /// No description provided for @demoQueued.
  ///
  /// In es, this message translates to:
  /// **'Demo · en cola'**
  String get demoQueued;

  /// No description provided for @demoValue.
  ///
  /// In es, this message translates to:
  /// **'Demo · {value}'**
  String demoValue(Object value);

  /// No description provided for @attachedContent.
  ///
  /// In es, this message translates to:
  /// **'Contenido adjunto'**
  String get attachedContent;

  /// No description provided for @demoNoFiles.
  ///
  /// In es, this message translates to:
  /// **'Demo · sin archivos'**
  String get demoNoFiles;

  /// No description provided for @eventDeleteHelp.
  ///
  /// In es, this message translates to:
  /// **'Al eliminar un evento sus leads dejan de aparecer en la app. La hoja de cálculo no se toca.'**
  String get eventDeleteHelp;

  /// No description provided for @eventDeletedHelp.
  ///
  /// In es, this message translates to:
  /// **'Sus leads dejan de aparecer en la app. La hoja de cálculo no se toca.'**
  String get eventDeletedHelp;

  /// No description provided for @active.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get active;

  /// No description provided for @eventStats.
  ///
  /// In es, this message translates to:
  /// **'{date} · {leads}{pending}'**
  String eventStats(Object date, Object leads, Object pending);

  /// No description provided for @allEventsFiles.
  ///
  /// In es, this message translates to:
  /// **'Todos los eventos · {files}'**
  String allEventsFiles(Object files);

  /// No description provided for @eventFiles.
  ///
  /// In es, this message translates to:
  /// **'{event} · {files}'**
  String eventFiles(Object event, Object files);

  /// No description provided for @deleteLocalFileQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar {name} de la biblioteca local?'**
  String deleteLocalFileQuestion(Object name);

  /// No description provided for @previewTo.
  ///
  /// In es, this message translates to:
  /// **'Para: {name}'**
  String previewTo(Object name);

  /// No description provided for @demoFixture.
  ///
  /// In es, this message translates to:
  /// **'Fixture demo'**
  String get demoFixture;

  /// No description provided for @latestLeadData.
  ///
  /// In es, this message translates to:
  /// **'Con los datos del último lead capturado'**
  String get latestLeadData;

  /// No description provided for @emailPreviewServerHelp.
  ///
  /// In es, this message translates to:
  /// **'{source} · El aviso de privacidad y la baja se agregan del lado del servidor.'**
  String emailPreviewServerHelp(Object source);

  /// No description provided for @recentEventHelp.
  ///
  /// In es, this message translates to:
  /// **'{date} · el más reciente. Si no está, agrégalo con +.'**
  String recentEventHelp(Object date);

  /// No description provided for @selectedCardPreview.
  ///
  /// In es, this message translates to:
  /// **'Vista previa de la tarjeta seleccionada'**
  String get selectedCardPreview;

  /// No description provided for @noCardPhotoSemantics.
  ///
  /// In es, this message translates to:
  /// **'Sin foto de tarjeta'**
  String get noCardPhotoSemantics;

  /// No description provided for @chooseLeadType.
  ///
  /// In es, this message translates to:
  /// **'Elige Proveedor, Partner o Cliente'**
  String get chooseLeadType;

  /// No description provided for @contentAttachmentSummary.
  ///
  /// In es, this message translates to:
  /// **'{selected} de {total} archivos de {event} se adjuntan al correo.'**
  String contentAttachmentSummary(Object event, Object selected, Object total);

  /// No description provided for @thisEventLower.
  ///
  /// In es, this message translates to:
  /// **'este evento'**
  String get thisEventLower;

  /// No description provided for @transcriptionDemo.
  ///
  /// In es, this message translates to:
  /// **'TRANSCRIPCIÓN · DEMO'**
  String get transcriptionDemo;

  /// No description provided for @demoTranscript.
  ///
  /// In es, this message translates to:
  /// **'Platicamos sobre el siguiente paso y el material que se compartirá. Confirmar seguimiento después del evento.'**
  String get demoTranscript;

  /// No description provided for @directPlacePersistentHelp.
  ///
  /// In es, this message translates to:
  /// **'Dónde surgió la conversación. Sustituye {lugar} en el correo; se conserva para la siguiente captura.'**
  String directPlacePersistentHelp(Object lugar);

  /// No description provided for @exportLeadSummary.
  ///
  /// In es, this message translates to:
  /// **'{leads} de {event}, con notas y datos de contacto.'**
  String exportLeadSummary(Object event, Object leads);

  /// No description provided for @exportDemoMessage.
  ///
  /// In es, this message translates to:
  /// **'Exportación {format} es solo una vista demo.'**
  String exportDemoMessage(Object format);

  /// No description provided for @waitingForSignal.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 registros esperan señal} =1{1 registro espera señal} other{{count} registros esperan señal}}'**
  String waitingForSignal(num count);

  /// No description provided for @syncDemoMessage.
  ///
  /// In es, this message translates to:
  /// **'Sincronización demo: no se enviaron datos.'**
  String get syncDemoMessage;

  /// No description provided for @pauseVoiceNote.
  ///
  /// In es, this message translates to:
  /// **'Pausar nota de voz'**
  String get pauseVoiceNote;

  /// No description provided for @playVoiceNote.
  ///
  /// In es, this message translates to:
  /// **'Reproducir nota de voz'**
  String get playVoiceNote;

  /// No description provided for @noCardPhotoDetail.
  ///
  /// In es, this message translates to:
  /// **'Sin foto de la tarjeta'**
  String get noCardPhotoDetail;

  /// No description provided for @contact.
  ///
  /// In es, this message translates to:
  /// **'Contacto'**
  String get contact;

  /// No description provided for @transcription.
  ///
  /// In es, this message translates to:
  /// **'Transcripción'**
  String get transcription;

  /// No description provided for @recordDetails.
  ///
  /// In es, this message translates to:
  /// **'Registro'**
  String get recordDetails;

  /// No description provided for @inSheet.
  ///
  /// In es, this message translates to:
  /// **'En la hoja'**
  String get inSheet;

  /// No description provided for @createFirstEvent.
  ///
  /// In es, this message translates to:
  /// **'Crea el primero para comenzar a capturar.'**
  String get createFirstEvent;

  /// No description provided for @leadsLabel.
  ///
  /// In es, this message translates to:
  /// **'leads'**
  String get leadsLabel;

  /// No description provided for @returnToCaptureIn.
  ///
  /// In es, this message translates to:
  /// **'Regresas a captura en {seconds} s'**
  String returnToCaptureIn(Object seconds);

  /// No description provided for @eventCreationHelp.
  ///
  /// In es, this message translates to:
  /// **'Queda activo y los leads que captures se guardan ahí.'**
  String get eventCreationHelp;

  /// No description provided for @eventAssignmentCount.
  ///
  /// In es, this message translates to:
  /// **'¿En qué eventos aplica? · {selected} de {total}'**
  String eventAssignmentCount(Object selected, Object total);

  /// No description provided for @selectedOfTotal.
  ///
  /// In es, this message translates to:
  /// **'{selected} de {total}'**
  String selectedOfTotal(Object selected, Object total);

  /// No description provided for @defaultEmailSubject.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento · {location}'**
  String defaultEmailSubject(Object location);

  /// No description provided for @defaultEmailBody.
  ///
  /// In es, this message translates to:
  /// **'Hola {name},\n\nGusto en coincidir en {location}. Te comparto la información que platicamos:\n\n{content}\n\nQuedo al pendiente.\n\nSaludos,\n{capturedBy}'**
  String defaultEmailBody(
    Object capturedBy,
    Object content,
    Object location,
    Object name,
  );

  /// No description provided for @unclosedVariable.
  ///
  /// In es, this message translates to:
  /// **'Hay una variable con llaves sin cerrar.'**
  String get unclosedVariable;

  /// No description provided for @invalidVariable.
  ///
  /// In es, this message translates to:
  /// **'Variable no válida: {variables}'**
  String invalidVariable(Object variables);

  /// No description provided for @demoAttachments.
  ///
  /// In es, this message translates to:
  /// **'• Scanley IMS · Ficha técnica · 1.2 MB\n• Vision AI · Casos de uso · 940 KB'**
  String get demoAttachments;

  /// No description provided for @noAttachments.
  ///
  /// In es, this message translates to:
  /// **'Sin archivos adjuntos'**
  String get noAttachments;

  /// No description provided for @demoOffice.
  ///
  /// In es, this message translates to:
  /// **'Oficinas de Grupo Lácteo'**
  String get demoOffice;

  /// No description provided for @leadCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 leads} =1{1 lead} other{{count} leads}}'**
  String leadCount(num count);

  /// No description provided for @eventCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 eventos} =1{1 evento} other{{count} eventos}}'**
  String eventCount(num count);

  /// No description provided for @pendingCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 por subir} =1{1 por subir} other{{count} por subir}}'**
  String pendingCount(num count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
