# Serves the registry as a manifest for the @zarpay/amounts JavaScript client.
#
# The frontend fetches this once and builds its client from it:
#
#   const amounts = Amounts.fromManifest(await (await fetch("/amounts/manifest")).json());
#
# Every locale the app ships is resolved into the manifest, so the client can
# format and parse in any of them without I18n.
class AmountsManifestsController < ActionController::API
  def show
    render json: Amount.manifest(locales: I18n.available_locales)
  end
end
