import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class S {
  static final locale = ValueNotifier(const Locale('it'));

  static const supportedLocales = [
    Locale('it'),
    Locale('en'),
    Locale('es'),
    Locale('de'),
  ];

  static const localeLabels = {
    'it': 'Italiano',
    'en': 'English',
    'es': 'Español',
    'de': 'Deutsch',
  };

  static const localeFlags = {
    'it': '🇮🇹',
    'en': '🇬🇧',
    'es': '🇪🇸',
    'de': '🇩🇪',
  };

  static String tr(String key) {
    return _t[locale.value.languageCode]?[key] ?? _t['en']?[key] ?? key;
  }

  static String trWith(String key, Map<String, String> params) {
    var s = tr(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  /// Messaggio login/registrazione localizzato (niente codici tipo "[internal-error]").
  static String authFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return tr('authErrorInvalidEmail');
      case 'wrong-password':
        return tr('authErrorWrongPassword');
      case 'user-not-found':
        return tr('authErrorUserNotFound');
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return tr('authErrorInvalidCredential');
      case 'too-many-requests':
        return tr('authErrorTooManyRequests');
      case 'network-request-failed':
        return tr('authErrorNetwork');
      case 'email-already-in-use':
        return tr('authErrorEmailInUse');
      case 'weak-password':
        return tr('authErrorWeakPassword');
      case 'user-disabled':
        return tr('authErrorUserDisabled');
      case 'operation-not-allowed':
        return tr('authErrorOperationNotAllowed');
      case 'internal-error':
      case '8':
        return tr('authErrorInternal');
      default:
        return tr('authErrorGeneric');
    }
  }

  static const Map<String, Map<String, String>> _t = {
    // ─── ITALIANO ───
    'it': {
      'appName': 'Scudo',
      'subtitle': 'La tua rete di sicurezza personale',
      'subtitleFull':
          'Avvisa chi ti sta intorno in caso di pericolo.',
      'login': 'Accedi',
      'register': 'Crea account',
      'yourName': 'Il tuo nome',
      'email': 'Email',
      'password': 'Password',
      'hasAccount': 'Hai già un account? Accedi',
      'noAccount': 'Non hai un account? Registrati',
      'insertName': 'Inserisci il tuo nome.',
      'networkActive': 'Rete attiva',
      'usersOnNetwork': '{n} utenti nella rete',
      'networkLoading': 'Rete attiva…',
      'sosHint':
          'Tocca il pulsante in caso di pericolo per avvisare chi ti è vicino.',
      'sendingAlarm': 'Invio allarme in corso…',
      'allNearbyNotified':
          'Tutti gli utenti nelle vicinanze riceveranno la tua posizione.',
      'cancelAlarm': 'ANNULLA ALLARME',
      'alarmSent': 'ALLARME INVIATO',
      'peopleNotified':
          '{name}, le persone entro 500 m sono state avvisate e vedono la tua posizione in tempo reale.',
      'call112': 'Chiama il 112',
      'callAuthorities': 'Chiama 112 (Forze dell\'Ordine)',
      'imSafe': 'Sono al sicuro',
      'helpRequest': 'RICHIESTA DI AIUTO',
      'approxDistance': 'A circa {n} metri da te',
      'calculatingDistance': 'Calcolo distanza…',
      'activatedAlarm':
          'Ha attivato l\'allarme di emergenza. Potrebbe essere in pericolo.',
      'seePosition': 'Vedi posizione in tempo reale',
      'ignore': 'Ignora (non posso aiutare ora)',
      'reach': 'Raggiungi {name}',
      'metersAway': '{n} metri dalla tua posizione',
      'updatingPosition': 'Aggiornamento posizione…',
      'closeMap': 'Chiudi mappa',
      'retry': 'Riprova',
      'loadingMap': 'Caricamento mappa…',
      'waitingPosition': 'In attesa della posizione…',
      'emergencyNotFound': 'Emergenza non trovata.',
      'networkTimeout': 'Timeout rete: riprova.',
      'activeEmergencies': 'Emergenze attive',
      'peopleInDanger': 'Persone in pericolo',
      'noActiveEmergencies': 'Nessuna emergenza attiva nelle vicinanze',
      'everyoneSafe': 'Tutti al sicuro!',
      'language': 'Lingua',
      'settings': 'Impostazioni',
      'you': 'TU',
      'locationPermission':
          'Attiva i permessi di posizione per inviare l\'allarme.',
      'user': 'Utente',
      'ago': 'fa',
      'seconds': 'secondi',
      'minutes': 'minuti',
      'hours': 'ore',
      'helpSomeone': 'Aiuta',
      'viewOnMap': 'Mappa',
      'firebaseError': 'Firebase non si è avviato',
      'checkConfig':
          'Controlla google-services.json (Android), GoogleService-Info.plist (iOS) e firebase_options.dart.',
      'emergencies': 'Emergenze',
      'home': 'Home',
      'alarmActive': 'Allarme attivo',
      'timeActive': 'Attivo da {t}',
      'profile': 'Profilo',
      'accountSection': 'Account',
      'tapToAddPhoto': 'Tocca l\'immagine per cambiare foto',
      'chooseFromGallery': 'Scegli dalla galleria',
      'takePhoto': 'Scatta foto',
      'saveChanges': 'Salva modifiche',
      'profileSaved': 'Profilo aggiornato',
      'photoUploadError': 'Impossibile caricare la foto. Riprova.',
      'addPhotoOptional': 'Foto profilo (opzionale)',
      'confirmPassword': 'Conferma password',
      'passwordMismatch': 'Le password non coincidono.',
      'passwordTooShort': 'La password deve essere di almeno 8 caratteri.',
      'verifyEmailTitle': 'Verifica la tua email',
      'verifyEmailBody':
          'Ti abbiamo inviato un link a {email}. Apri la mail e tocca il link per attivare l\'account.',
      'verifyEmailResend': 'Invia di nuovo l\'email',
      'verifyEmailCheck': 'Ho già verificato',
      'verifyEmailSignOut': 'Esci',
      'verifyEmailCooldown': 'Riprova tra {n} s',
      'verifyEmailSent': 'Email di verifica inviata.',
      'verifyEmailSpamHint':
          'Se non arriva, controlla anche spam e posta indesiderata.',
      'verifyEmailNotVerifiedTitle': 'Email non ancora verificata',
      'verifyEmailNotVerifiedBody':
          'Assicurati di aver toccato il link nell\'email che ti abbiamo inviato. Se l\'hai già fatto, attendi qualche secondo e riprova, oppure controlla spam e posta indesiderata.',
      'forgotPassword': 'Password dimenticata?',
      'resetPasswordTitle': 'Recupera password',
      'resetPasswordHint':
          'Inserisci l\'email: riceverai un link per reimpostare la password.',
      'resetPasswordSend': 'Invia link',
      'resetPasswordSent':
          'Controlla la posta e segui il link per reimpostare la password.',
      'resetPasswordError':
          'Impossibile inviare l\'email. Controlla l\'indirizzo.',
      'cancel': 'Annulla',
      'changePassword': 'Cambia password',
      'currentPassword': 'Password attuale',
      'newPassword': 'Nuova password',
      'confirmNewPassword': 'Conferma nuova password',
      'changePasswordSuccess': 'Password aggiornata.',
      'changePasswordError': 'Impossibile aggiornare la password.',
      'changePasswordWrongCurrent': 'Password attuale non corretta.',
      'changePasswordOnlyEmail':
          'Disponibile solo se accedi con email e password.',
      'deleteAccount': 'Elimina account',
      'deleteAccountConfirmTitle': 'Eliminare definitivamente l\'account?',
      'deleteAccountConfirmIntro': 'Verranno rimossi in modo definitivo:',
      'deleteAccountConfirmBullet1': 'Profilo e foto',
      'deleteAccountConfirmBullet2': 'Dati salvati sui nostri server',
      'deleteAccountConfirmBullet3': 'Accesso e notifiche push',
      'deleteAccountIrreversibleNote':
          'Non potrai recuperare l\'account. L\'azione non è reversibile.',
      'deleteAccountError': 'Impossibile eliminare l\'account. Riprova.',
      'deleteAccountConfirmButton': 'Sì, elimina definitivamente',
      'logoutConfirmTitle': 'Uscire dall\'account?',
      'logoutConfirmBody':
          'Verrai disconnesso dall\'app. Potrai accedere di nuovo quando vorrai.',
      'logoutConfirmAction': 'Esci',
      'authErrorInvalidEmail': 'Indirizzo email non valido.',
      'authErrorWrongPassword': 'Password non corretta.',
      'authErrorUserNotFound': 'Nessun account con questa email.',
      'authErrorInvalidCredential': 'Email o password non corretti.',
      'authErrorTooManyRequests': 'Troppi tentativi. Riprova tra poco.',
      'authErrorNetwork': 'Errore di rete. Controlla la connessione.',
      'authErrorEmailInUse': 'Questa email è già registrata.',
      'authErrorWeakPassword': 'Password troppo debole.',
      'authErrorUserDisabled': 'Questo account è stato disabilitato.',
      'authErrorOperationNotAllowed':
          'Accesso non consentito. Contatta il supporto.',
      'authErrorInternal': 'Errore del servizio. Riprova tra poco.',
      'authErrorGeneric': 'Accesso non riuscito. Riprova.',
      'userSafeTitle': 'Allarme terminato',
      'userSafeMessage': '{name} è al sicuro.',
      'ok': 'OK',
    },

    // ─── ENGLISH ───
    'en': {
      'appName': 'Scudo',
      'subtitle': 'Your personal safety network',
      'subtitleFull': 'Alert people around you in case of danger.',
      'login': 'Sign in',
      'register': 'Create account',
      'yourName': 'Your name',
      'email': 'Email',
      'password': 'Password',
      'hasAccount': 'Already have an account? Sign in',
      'noAccount': 'Don\'t have an account? Register',
      'insertName': 'Please enter your name.',
      'networkActive': 'Network active',
      'usersOnNetwork': '{n} users on the network',
      'networkLoading': 'Network active…',
      'sosHint': 'Tap the button in case of danger to alert people near you.',
      'sendingAlarm': 'Sending alarm…',
      'allNearbyNotified':
          'All nearby users will receive your position.',
      'cancelAlarm': 'CANCEL ALARM',
      'alarmSent': 'ALARM SENT',
      'peopleNotified':
          '{name}, people within 500 m have been alerted and can see your real-time position.',
      'call112': 'Call 112',
      'callAuthorities': 'Call 112 (Emergency Services)',
      'imSafe': 'I\'m safe',
      'helpRequest': 'HELP REQUEST',
      'approxDistance': 'About {n} meters from you',
      'calculatingDistance': 'Calculating distance…',
      'activatedAlarm':
          'Activated the emergency alarm. May be in danger.',
      'seePosition': 'See real-time position',
      'ignore': 'Ignore (can\'t help now)',
      'reach': 'Reach {name}',
      'metersAway': '{n} meters from your position',
      'updatingPosition': 'Updating position…',
      'closeMap': 'Close map',
      'retry': 'Retry',
      'loadingMap': 'Loading map…',
      'waitingPosition': 'Waiting for position…',
      'emergencyNotFound': 'Emergency not found.',
      'networkTimeout': 'Network timeout: retry.',
      'activeEmergencies': 'Active emergencies',
      'peopleInDanger': 'People in danger',
      'noActiveEmergencies': 'No active emergencies nearby',
      'everyoneSafe': 'Everyone is safe!',
      'language': 'Language',
      'settings': 'Settings',
      'you': 'YOU',
      'locationPermission':
          'Enable location permissions to send the alarm.',
      'user': 'User',
      'ago': 'ago',
      'seconds': 'seconds',
      'minutes': 'minutes',
      'hours': 'hours',
      'helpSomeone': 'Help',
      'viewOnMap': 'Map',
      'firebaseError': 'Firebase failed to start',
      'checkConfig':
          'Check google-services.json (Android), GoogleService-Info.plist (iOS) and firebase_options.dart.',
      'emergencies': 'Emergencies',
      'home': 'Home',
      'alarmActive': 'Alarm active',
      'timeActive': 'Active for {t}',
      'profile': 'Profile',
      'accountSection': 'Account',
      'tapToAddPhoto': 'Tap the image to change photo',
      'chooseFromGallery': 'Choose from gallery',
      'takePhoto': 'Take photo',
      'saveChanges': 'Save changes',
      'profileSaved': 'Profile updated',
      'photoUploadError': 'Could not upload photo. Try again.',
      'addPhotoOptional': 'Profile photo (optional)',
      'confirmPassword': 'Confirm password',
      'passwordMismatch': 'Passwords do not match.',
      'passwordTooShort': 'Password must be at least 8 characters.',
      'verifyEmailTitle': 'Verify your email',
      'verifyEmailBody':
          'We sent a link to {email}. Open the email and tap the link to activate your account.',
      'verifyEmailResend': 'Resend email',
      'verifyEmailCheck': 'I have verified',
      'verifyEmailSignOut': 'Sign out',
      'verifyEmailCooldown': 'Try again in {n} s',
      'verifyEmailSent': 'Verification email sent.',
      'verifyEmailSpamHint':
          'If you don\'t see it, check spam and junk folders.',
      'verifyEmailNotVerifiedTitle': 'Not verified yet',
      'verifyEmailNotVerifiedBody':
          'Make sure you tapped the link in the email we sent. If you already did, wait a few seconds and try again, or check spam and junk folders.',
      'forgotPassword': 'Forgot password?',
      'resetPasswordTitle': 'Reset password',
      'resetPasswordHint':
          'Enter your email: you will receive a link to reset your password.',
      'resetPasswordSend': 'Send link',
      'resetPasswordSent':
          'Check your inbox and follow the link to reset your password.',
      'resetPasswordError': 'Could not send email. Check the address.',
      'cancel': 'Cancel',
      'changePassword': 'Change password',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'confirmNewPassword': 'Confirm new password',
      'changePasswordSuccess': 'Password updated.',
      'changePasswordError': 'Could not update password.',
      'changePasswordWrongCurrent': 'Current password is incorrect.',
      'changePasswordOnlyEmail':
          'Only available when you sign in with email and password.',
      'deleteAccount': 'Delete account',
      'deleteAccountConfirmTitle': 'Delete your account permanently?',
      'deleteAccountConfirmIntro': 'The following will be permanently removed:',
      'deleteAccountConfirmBullet1': 'Profile and photo',
      'deleteAccountConfirmBullet2': 'Data stored on our servers',
      'deleteAccountConfirmBullet3': 'App access and push notifications',
      'deleteAccountIrreversibleNote':
          'You won\'t be able to recover your account. This cannot be undone.',
      'deleteAccountError': 'Could not delete account. Try again.',
      'deleteAccountConfirmButton': 'Yes, delete permanently',
      'logoutConfirmTitle': 'Sign out?',
      'logoutConfirmBody':
          'You will be logged out of the app. You can sign in again anytime.',
      'logoutConfirmAction': 'Sign out',
      'authErrorInvalidEmail': 'Invalid email address.',
      'authErrorWrongPassword': 'Incorrect password.',
      'authErrorUserNotFound': 'No account found for this email.',
      'authErrorInvalidCredential': 'Incorrect email or password.',
      'authErrorTooManyRequests': 'Too many attempts. Try again shortly.',
      'authErrorNetwork': 'Network error. Check your connection.',
      'authErrorEmailInUse': 'This email is already registered.',
      'authErrorWeakPassword': 'Password is too weak.',
      'authErrorUserDisabled': 'This account has been disabled.',
      'authErrorOperationNotAllowed':
          'Sign-in not allowed. Contact support.',
      'authErrorInternal': 'Service error. Try again shortly.',
      'authErrorGeneric': 'Sign-in failed. Try again.',
      'userSafeTitle': 'Alarm ended',
      'userSafeMessage': '{name} is safe.',
      'ok': 'OK',
    },

    // ─── ESPAÑOL ───
    'es': {
      'appName': 'Scudo',
      'subtitle': 'Tu red de seguridad personal',
      'subtitleFull':
          'Avisa a quienes te rodean en caso de peligro.',
      'login': 'Iniciar sesión',
      'register': 'Crear cuenta',
      'yourName': 'Tu nombre',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'hasAccount': '¿Ya tienes cuenta? Inicia sesión',
      'noAccount': '¿No tienes cuenta? Regístrate',
      'insertName': 'Ingresa tu nombre.',
      'networkActive': 'Red activa',
      'usersOnNetwork': '{n} usuarios en la red',
      'networkLoading': 'Red activa…',
      'sosHint':
          'Toca el botón en caso de peligro para avisar a quienes están cerca.',
      'sendingAlarm': 'Enviando alarma…',
      'allNearbyNotified':
          'Todos los usuarios cercanos recibirán tu ubicación.',
      'cancelAlarm': 'CANCELAR ALARMA',
      'alarmSent': 'ALARMA ENVIADA',
      'peopleNotified':
          '{name}, las personas en un radio de 500 m han sido alertadas y ven tu ubicación en tiempo real.',
      'call112': 'Llamar al 112',
      'callAuthorities': 'Llamar al 112 (Emergencias)',
      'imSafe': 'Estoy a salvo',
      'helpRequest': 'SOLICITUD DE AYUDA',
      'approxDistance': 'A unos {n} metros de ti',
      'calculatingDistance': 'Calculando distancia…',
      'activatedAlarm':
          'Ha activado la alarma de emergencia. Podría estar en peligro.',
      'seePosition': 'Ver ubicación en tiempo real',
      'ignore': 'Ignorar (no puedo ayudar ahora)',
      'reach': 'Llegar a {name}',
      'metersAway': '{n} metros de tu ubicación',
      'updatingPosition': 'Actualizando ubicación…',
      'closeMap': 'Cerrar mapa',
      'retry': 'Reintentar',
      'loadingMap': 'Cargando mapa…',
      'waitingPosition': 'Esperando ubicación…',
      'emergencyNotFound': 'Emergencia no encontrada.',
      'networkTimeout': 'Tiempo de espera agotado: reintenta.',
      'activeEmergencies': 'Emergencias activas',
      'peopleInDanger': 'Personas en peligro',
      'noActiveEmergencies': 'No hay emergencias activas cercanas',
      'everyoneSafe': '¡Todos están a salvo!',
      'language': 'Idioma',
      'settings': 'Ajustes',
      'you': 'TÚ',
      'locationPermission':
          'Activa los permisos de ubicación para enviar la alarma.',
      'user': 'Usuario',
      'ago': 'hace',
      'seconds': 'segundos',
      'minutes': 'minutos',
      'hours': 'horas',
      'helpSomeone': 'Ayudar',
      'viewOnMap': 'Mapa',
      'firebaseError': 'Firebase no se ha iniciado',
      'checkConfig':
          'Comprueba google-services.json (Android), GoogleService-Info.plist (iOS) y firebase_options.dart.',
      'emergencies': 'Emergencias',
      'home': 'Inicio',
      'alarmActive': 'Alarma activa',
      'timeActive': 'Activa desde hace {t}',
      'profile': 'Perfil',
      'accountSection': 'Cuenta',
      'tapToAddPhoto': 'Toca la imagen para cambiar la foto',
      'chooseFromGallery': 'Elegir de la galería',
      'takePhoto': 'Hacer foto',
      'saveChanges': 'Guardar cambios',
      'profileSaved': 'Perfil actualizado',
      'photoUploadError': 'No se pudo subir la foto. Inténtalo de nuevo.',
      'addPhotoOptional': 'Foto de perfil (opcional)',
      'confirmPassword': 'Confirmar contraseña',
      'passwordMismatch': 'Las contraseñas no coinciden.',
      'passwordTooShort': 'La contraseña debe tener al menos 8 caracteres.',
      'verifyEmailTitle': 'Verifica tu correo',
      'verifyEmailBody':
          'Enviamos un enlace a {email}. Abre el correo y pulsa el enlace para activar la cuenta.',
      'verifyEmailResend': 'Reenviar correo',
      'verifyEmailCheck': 'Ya he verificado',
      'verifyEmailSignOut': 'Cerrar sesión',
      'verifyEmailCooldown': 'Reintenta en {n} s',
      'verifyEmailSent': 'Correo de verificación enviado.',
      'verifyEmailSpamHint':
          'Si no lo ves, revisa también spam y correo no deseado.',
      'verifyEmailNotVerifiedTitle': 'Aún no verificado',
      'verifyEmailNotVerifiedBody':
          'Asegúrate de haber tocado el enlace del correo que te enviamos. Si ya lo hiciste, espera unos segundos e inténtalo de nuevo, o revisa spam y correo no deseado.',
      'forgotPassword': '¿Olvidaste la contraseña?',
      'resetPasswordTitle': 'Recuperar contraseña',
      'resetPasswordHint':
          'Introduce tu correo: recibirás un enlace para restablecer la contraseña.',
      'resetPasswordSend': 'Enviar enlace',
      'resetPasswordSent':
          'Revisa tu bandeja y sigue el enlace para restablecer la contraseña.',
      'resetPasswordError':
          'No se pudo enviar el correo. Comprueba la dirección.',
      'cancel': 'Cancelar',
      'changePassword': 'Cambiar contraseña',
      'currentPassword': 'Contraseña actual',
      'newPassword': 'Nueva contraseña',
      'confirmNewPassword': 'Confirmar nueva contraseña',
      'changePasswordSuccess': 'Contraseña actualizada.',
      'changePasswordError': 'No se pudo actualizar la contraseña.',
      'changePasswordWrongCurrent': 'La contraseña actual no es correcta.',
      'changePasswordOnlyEmail':
          'Solo disponible si inicias sesión con correo y contraseña.',
      'deleteAccount': 'Eliminar cuenta',
      'deleteAccountConfirmTitle': '¿Eliminar la cuenta para siempre?',
      'deleteAccountConfirmIntro': 'Se eliminará de forma permanente:',
      'deleteAccountConfirmBullet1': 'Perfil y foto',
      'deleteAccountConfirmBullet2': 'Datos guardados en nuestros servidores',
      'deleteAccountConfirmBullet3': 'Acceso y notificaciones',
      'deleteAccountIrreversibleNote':
          'No podrás recuperar la cuenta. Esta acción no se puede deshacer.',
      'deleteAccountError': 'No se pudo eliminar la cuenta. Inténtalo de nuevo.',
      'deleteAccountConfirmButton': 'Sí, eliminar para siempre',
      'logoutConfirmTitle': '¿Cerrar sesión?',
      'logoutConfirmBody':
          'Se cerrará la sesión en la app. Podrás volver a entrar cuando quieras.',
      'logoutConfirmAction': 'Cerrar sesión',
      'authErrorInvalidEmail': 'Correo electrónico no válido.',
      'authErrorWrongPassword': 'Contraseña incorrecta.',
      'authErrorUserNotFound': 'No hay cuenta con este correo.',
      'authErrorInvalidCredential': 'Correo o contraseña incorrectos.',
      'authErrorTooManyRequests': 'Demasiados intentos. Prueba más tarde.',
      'authErrorNetwork': 'Error de red. Comprueba la conexión.',
      'authErrorEmailInUse': 'Este correo ya está registrado.',
      'authErrorWeakPassword': 'Contraseña demasiado débil.',
      'authErrorUserDisabled': 'Esta cuenta está deshabilitada.',
      'authErrorOperationNotAllowed':
          'Inicio de sesión no permitido. Contacta con soporte.',
      'authErrorInternal': 'Error del servicio. Prueba más tarde.',
      'authErrorGeneric': 'No se pudo iniciar sesión. Inténtalo de nuevo.',
      'userSafeTitle': 'Alarma finalizada',
      'userSafeMessage': '{name} está a salvo.',
      'ok': 'OK',
    },

    // ─── DEUTSCH ───
    'de': {
      'appName': 'Scudo',
      'subtitle': 'Dein persönliches Sicherheitsnetzwerk',
      'subtitleFull':
          'Warne Menschen in deiner Nähe bei Gefahr.',
      'login': 'Anmelden',
      'register': 'Konto erstellen',
      'yourName': 'Dein Name',
      'email': 'E-Mail',
      'password': 'Passwort',
      'hasAccount': 'Bereits ein Konto? Anmelden',
      'noAccount': 'Kein Konto? Registrieren',
      'insertName': 'Bitte gib deinen Namen ein.',
      'networkActive': 'Netzwerk aktiv',
      'usersOnNetwork': '{n} Nutzer im Netzwerk',
      'networkLoading': 'Netzwerk aktiv…',
      'sosHint':
          'Drücke den Knopf bei Gefahr, um Personen in deiner Nähe zu warnen.',
      'sendingAlarm': 'Alarm wird gesendet…',
      'allNearbyNotified':
          'Alle Nutzer in der Nähe erhalten deine Position.',
      'cancelAlarm': 'ALARM ABBRECHEN',
      'alarmSent': 'ALARM GESENDET',
      'peopleNotified':
          '{name}, Personen im Umkreis von 500 m wurden gewarnt und sehen deine Echtzeit-Position.',
      'call112': '112 anrufen',
      'callAuthorities': '112 anrufen (Notruf)',
      'imSafe': 'Ich bin in Sicherheit',
      'helpRequest': 'HILFERUF',
      'approxDistance': 'Etwa {n} Meter von dir',
      'calculatingDistance': 'Entfernung wird berechnet…',
      'activatedAlarm':
          'Hat den Notfallalarm ausgelöst. Könnte in Gefahr sein.',
      'seePosition': 'Echtzeit-Position anzeigen',
      'ignore': 'Ignorieren (kann jetzt nicht helfen)',
      'reach': '{name} erreichen',
      'metersAway': '{n} Meter von deiner Position',
      'updatingPosition': 'Position wird aktualisiert…',
      'closeMap': 'Karte schließen',
      'retry': 'Erneut versuchen',
      'loadingMap': 'Karte wird geladen…',
      'waitingPosition': 'Warte auf Position…',
      'emergencyNotFound': 'Notfall nicht gefunden.',
      'networkTimeout': 'Netzwerk-Timeout: erneut versuchen.',
      'activeEmergencies': 'Aktive Notfälle',
      'peopleInDanger': 'Personen in Gefahr',
      'noActiveEmergencies': 'Keine aktiven Notfälle in der Nähe',
      'everyoneSafe': 'Alle sind in Sicherheit!',
      'language': 'Sprache',
      'settings': 'Einstellungen',
      'you': 'DU',
      'locationPermission':
          'Aktiviere die Standortberechtigung, um den Alarm zu senden.',
      'user': 'Nutzer',
      'ago': 'vor',
      'seconds': 'Sekunden',
      'minutes': 'Minuten',
      'hours': 'Stunden',
      'helpSomeone': 'Helfen',
      'viewOnMap': 'Karte',
      'firebaseError': 'Firebase konnte nicht gestartet werden',
      'checkConfig':
          'Prüfe google-services.json (Android), GoogleService-Info.plist (iOS) und firebase_options.dart.',
      'emergencies': 'Notfälle',
      'home': 'Start',
      'alarmActive': 'Alarm aktiv',
      'timeActive': 'Aktiv seit {t}',
      'profile': 'Profil',
      'accountSection': 'Konto',
      'tapToAddPhoto': 'Tippe auf das Bild, um das Foto zu ändern',
      'chooseFromGallery': 'Aus Galerie wählen',
      'takePhoto': 'Foto aufnehmen',
      'saveChanges': 'Änderungen speichern',
      'profileSaved': 'Profil aktualisiert',
      'photoUploadError': 'Foto konnte nicht hochgeladen werden.',
      'addPhotoOptional': 'Profilfoto (optional)',
      'confirmPassword': 'Passwort bestätigen',
      'passwordMismatch': 'Die Passwörter stimmen nicht überein.',
      'passwordTooShort': 'Das Passwort muss mindestens 8 Zeichen haben.',
      'verifyEmailTitle': 'E-Mail bestätigen',
      'verifyEmailBody':
          'Wir haben einen Link an {email} gesendet. Öffne die E-Mail und tippe auf den Link.',
      'verifyEmailResend': 'E-Mail erneut senden',
      'verifyEmailCheck': 'Ich habe bestätigt',
      'verifyEmailSignOut': 'Abmelden',
      'verifyEmailCooldown': 'Erneut in {n} s',
      'verifyEmailSent': 'Bestätigungs-E-Mail gesendet.',
      'verifyEmailSpamHint':
          'Falls sie nicht ankommt, prüfe auch Spam und Junk.',
      'verifyEmailNotVerifiedTitle': 'Noch nicht bestätigt',
      'verifyEmailNotVerifiedBody':
          'Stelle sicher, dass du den Link in unserer E-Mail angetippt hast. Wenn du das schon getan hast, warte kurz und versuche es erneut, oder prüfe Spam und Junk.',
      'forgotPassword': 'Passwort vergessen?',
      'resetPasswordTitle': 'Passwort zurücksetzen',
      'resetPasswordHint':
          'Gib deine E-Mail ein: du erhältst einen Link zum Zurücksetzen.',
      'resetPasswordSend': 'Link senden',
      'resetPasswordSent':
          'Prüfe dein Postfach und folge dem Link zum Zurücksetzen.',
      'resetPasswordError':
          'E-Mail konnte nicht gesendet werden. Adresse prüfen.',
      'cancel': 'Abbrechen',
      'changePassword': 'Passwort ändern',
      'currentPassword': 'Aktuelles Passwort',
      'newPassword': 'Neues Passwort',
      'confirmNewPassword': 'Neues Passwort bestätigen',
      'changePasswordSuccess': 'Passwort aktualisiert.',
      'changePasswordError': 'Passwort konnte nicht geändert werden.',
      'changePasswordWrongCurrent': 'Aktuelles Passwort ist falsch.',
      'changePasswordOnlyEmail':
          'Nur bei Anmeldung mit E-Mail und Passwort möglich.',
      'deleteAccount': 'Konto löschen',
      'deleteAccountConfirmTitle': 'Konto endgültig löschen?',
      'deleteAccountConfirmIntro': 'Folgendes wird dauerhaft entfernt:',
      'deleteAccountConfirmBullet1': 'Profil und Foto',
      'deleteAccountConfirmBullet2': 'Auf unseren Servern gespeicherte Daten',
      'deleteAccountConfirmBullet3': 'Zugang und Push-Benachrichtigungen',
      'deleteAccountIrreversibleNote':
          'Eine Wiederherstellung ist nicht möglich.',
      'deleteAccountError': 'Konto konnte nicht gelöscht werden.',
      'deleteAccountConfirmButton': 'Ja, endgültig löschen',
      'logoutConfirmTitle': 'Abmelden?',
      'logoutConfirmBody':
          'Du wirst aus der App abgemeldet. Du kannst dich jederzeit wieder anmelden.',
      'logoutConfirmAction': 'Abmelden',
      'authErrorInvalidEmail': 'Ungültige E-Mail-Adresse.',
      'authErrorWrongPassword': 'Falsches Passwort.',
      'authErrorUserNotFound': 'Kein Konto mit dieser E-Mail.',
      'authErrorInvalidCredential': 'E-Mail oder Passwort falsch.',
      'authErrorTooManyRequests': 'Zu viele Versuche. Kurz warten.',
      'authErrorNetwork': 'Netzwerkfehler. Verbindung prüfen.',
      'authErrorEmailInUse': 'Diese E-Mail ist bereits registriert.',
      'authErrorWeakPassword': 'Passwort zu schwach.',
      'authErrorUserDisabled': 'Dieses Konto wurde deaktiviert.',
      'authErrorOperationNotAllowed':
          'Anmeldung nicht erlaubt. Support kontaktieren.',
      'authErrorInternal': 'Dienstfehler. Kurz später erneut versuchen.',
      'authErrorGeneric': 'Anmeldung fehlgeschlagen. Erneut versuchen.',
      'userSafeTitle': 'Alarm beendet',
      'userSafeMessage': '{name} ist in Sicherheit.',
      'ok': 'OK',
    },
  };
}
