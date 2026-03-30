/// Durante [deleteAccountViaServer] il server può già aver rimosso l'utente Auth
/// mentre il client ha ancora un token valido per pochi ms: posizione e
/// `userChanges` (sync FCM) altrimenti riscriverebbero `users/{uid}`.
class AccountDeletionGuard {
  AccountDeletionGuard._();

  /// True mentre è in corso [UserService.deleteAccountViaServer] lato profilo.
  static bool inProgress = false;
}
