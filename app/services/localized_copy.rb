module LocalizedCopy
  module_function

  def call(bg, en)
    I18n.locale == :en ? en : bg
  end
end
