# Capybara 3.40.0 + Chrome 158 以降で、セッションのリセット時に
# "invalid argument: * is not a valid URL" になる問題の暫定対処。
# https://github.com/teamcapybara/capybara/issues/2865
# 公式修正がリリースされ Capybara を更新したら、このファイルごと削除する。
if Gem.loaded_specs.fetch("capybara").version == Gem::Version.new("3.40.0")
  module ClearStorageWithoutWildcardOrigin
    private

    def execute_cdp(cmd, params = {})
      return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

      types = params[:storageTypes].to_s.split(",")
      super("Network.clearBrowserCookies") if types.delete("cookies")

      origin = Capybara.current_session.server&.base_url
      super(cmd, params.merge(origin: origin, storageTypes: types.join(","))) if origin && types.any?
    end
  end

  Capybara::Selenium::Driver::ChromeDriver.prepend(ClearStorageWithoutWildcardOrigin)
end
