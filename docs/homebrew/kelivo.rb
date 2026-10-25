# Draft for homebrew/homebrew-cask. Do not submit until version and sha256
# match a Developer ID-signed, notarized GitHub release.
# Setup and submission notes: docs/macos-signing.md
cask "kelivo" do
  version "1.3.1,80"
  sha256 "REPLACE_WITH_SHA256_OF_THE_SIGNED_DMG"

  url "https://github.com/Chevey339/kelivo/releases/download/v#{version.csv.first}/Kelivo_macos_#{version.csv.first}%2B#{version.csv.second}.dmg"
  name "Kelivo"
  desc "Multi-platform, multi-provider LLM chat client"
  homepage "https://kelivo.psycheas.top/"

  livecheck do
    url :url
    regex(/^Kelivo[._-]macos[._-]v?(\d+(?:\.\d+)+)\+(\d+)\.dmg$/i)
    strategy :github_latest do |json, regex|
      json["assets"]&.map do |asset|
        match = asset["name"]&.match(regex)
        next if match.blank?

        "#{match[1]},#{match[2]}"
      end
    end
  end

  depends_on macos: :monterey

  app "kelivo.app"

  zap trash: [
    "~/Library/Application Support/com.psyche.kelivo",
    "~/Library/Caches/com.psyche.kelivo",
    "~/Library/Preferences/com.psyche.kelivo.plist",
    "~/Library/Saved Application State/com.psyche.kelivo.savedState",
  ]
end
