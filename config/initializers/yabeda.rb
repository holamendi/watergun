Yabeda.configure do
  register_adapter(:honeybadger_insights, Yabeda::HoneybadgerInsights::Adapter.new)
end
