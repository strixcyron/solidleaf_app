/// GitHub API configuration for release downloads.
///
/// The premium repository (`FrauxHD/PREMIUM`) is private and requires a
/// Personal Access Token with `repo` scope. Pass it at build time:
///
/// `flutter run --dart-define=GITHUB_TOKEN=ghp_...`
///
/// Never commit real tokens to source control.
class GitHubConfig {
  GitHubConfig._();

  /// PAT used only for authenticated requests to the private premium repo.
  static String get premiumToken {
    const override = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
    return override;
  }

  static bool get hasPremiumToken => premiumToken.isNotEmpty;
}
