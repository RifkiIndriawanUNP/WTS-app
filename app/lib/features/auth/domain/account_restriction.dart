/// Data untuk layar "akun ditangguhkan / diblokir".
class AccountRestriction {
  const AccountRestriction.suspended(DateTime this.until) : banned = false;
  const AccountRestriction.banned() : banned = true, until = null;

  final bool banned;

  /// Akhir masa penangguhan (hanya untuk suspended).
  final DateTime? until;
}
