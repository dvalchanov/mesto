require "rails_helper"

RSpec.describe "Standalone calculators", type: :system do
  after do
    page.execute_script(<<~JS)
      document.querySelectorAll("[data-controller~='calculator-form']").forEach((element) => {
        element.setAttribute("data-calculator-form-draft-enabled-value", "false")
      })
      window.sessionStorage.clear()
    JS
  rescue StandardError
    nil
  end

  def choose_custom_select(label, option, within: page)
    native_select = within.find_field(label, visible: :all)
    native_select.find(:xpath, "..").find(".select-menu__trigger").click
    page.find('.select-menu__options:not([hidden]) .select-menu__option', text: option, exact_text: true).click
  end

  it "supports a visitor with no property and an explicit example scenario" do
    visit purchase_calculator_path
    expect(page).to have_css("h1", text: "Колко ще ти струва покупката - и кога ще ти трябват парите?")
    expect(page).to have_css(".calculator-plan-visual")
    expect(page).to have_link("Започни сметката", href: "#purchase-calculator")
    expect(page).to have_link("Виж примерна сметка", href: purchase_calculator_path(example: 1))
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.calculator-hero')).backgroundImage")).to eq("none")
    select_style = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector('select'))
        return { appearance: style.appearance, paddingRight: style.paddingRight, backgroundImage: style.backgroundImage }
      })()
    JS
    expect(select_style.fetch("appearance")).to eq("none")
    expect(select_style.fetch("paddingRight")).to eq("48px")
    expect(select_style.fetch("backgroundImage")).not_to eq("none")
    expect(page).to have_field("Цена по сделката", with: "")
    expect(page).to have_no_button("Започни отначало")
    find(".summary-warnings > summary").click
    expect(page).to have_text("Въведи цена, за да започне изчислението")

    example_action = find_link("Зареди примерните данни")
    expect(example_action[:class]).to include("button--outline", "button--small")
    example_action.click
    expect(page).to have_field("Цена по сделката", with: "300000")
    expect(page).to have_button("Започни отначало")
    expect(find_button("Започни отначало")).to have_css("svg")
    expect(page).to have_text("Общо планирани плащания")
  end

  it "calculates a cash-only purchase without an account" do
    visit purchase_calculator_path
    fill_in "Цена по сделката", with: "100000"
    expect(page).to have_button("Започни отначало")
    click_button "Преизчисли", match: :first

    expect(page).to have_text("Цена за плащане")
    expect(page).to have_text("100 000,00 €")
    expect(page).to have_text("Месечна вноска")
  end

  it "uses the focused mortgage entry point" do
    visit mortgage_calculator_path
    expect(page).to have_no_button("Изчисли")
    expect(find_link("Виж примерна сметка")[:class]).to include("button--outline", "button--small")
    expect(page).to have_no_css(".summary-empty > span")
    fill_in "Размер на кредита", with: "120000"
    fill_in "Годишна номинална лихва", with: "0"
    fill_in "Срок", with: "10"

    expect(page).to have_text("1 000,00 €")
    expect(page).to have_text("Обща лихва")
    year_unit = find_field("Срок").find(:xpath, "..").find("span")
    expect(year_unit.rect.width).to be >= 76

    calculation = find(".summary-calculation")
    calculation_layout = page.evaluate_script(<<~JS, calculation)
      (() => {
        const section = arguments[0]
        return {
          borderWidth: getComputedStyle(section).borderTopWidth,
          titleLeft: section.querySelector("h3").getBoundingClientRect().left,
          paragraphLeft: section.querySelector("p").getBoundingClientRect().left,
          assumptionLeft: section.querySelector("li").getBoundingClientRect().left
        }
      })()
    JS
    expect(calculation_layout.fetch("borderWidth")).to eq("0px")
    expect([ calculation_layout.fetch("paragraphLeft"), calculation_layout.fetch("assumptionLeft") ]).to all(be_within(1).of(calculation_layout.fetch("titleLeft")))
  end

  it "waits for a mortgage field to blur before validating an unfinished value" do
    visit mortgage_calculator_path
    fill_in "Размер на кредита", with: "100000"
    fill_in "Годишна номинална лихва", with: "2"
    fill_in "Срок", with: "30"
    find(".calculator-panel__heading").click
    expect(page).to have_text("Обща лихва")

    interest = find_field("Годишна номинална лихва")
    interest.click
    interest.send_keys([ :meta, "a" ], "2.")
    sleep 0.6

    expect(page).to have_no_css(".calculator-warning")
    expect(page.evaluate_script("window.sessionStorage.getItem('mesto:calculator-draft:mortgage:v1')")).to be_present

    find_field("Срок").click
    expect(page).to have_css(".calculator-warning", text: "Въведи положително число")
  end

  it "keeps financing controls evenly spaced and aligned" do
    visit purchase_calculator_path(example: 1)
    click_button "02 Финансиране"

    layout = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('[data-section="financing"].calculator-panel')
        const modeChoice = panel.querySelector('fieldset')
        const details = panel.querySelector('.calculator-financing-details')
        const startingCash = panel.querySelector('#calculator_starting_cash').closest('.money-field')
        const reserve = panel.querySelector('#calculator_reserve').closest('.money-field')
        const yearUnit = panel.querySelector('#calculator_term_years').nextElementSibling
        const fundingBasics = panel.querySelector('.calculator-fields--funding-basics')
        const note = panel.querySelector('.calculator-financing-note')
        const noteStyle = getComputedStyle(note)

        return {
          detailGap: details.getBoundingClientRect().top - modeChoice.getBoundingClientRect().bottom,
          cashTop: startingCash.getBoundingClientRect().top,
          reserveTop: reserve.getBoundingClientRect().top,
          yearUnitWidth: yearUnit.getBoundingClientRect().width,
          noteGap: note.getBoundingClientRect().top - fundingBasics.getBoundingClientRect().bottom,
          noteLines: (note.clientHeight - parseFloat(noteStyle.paddingTop) - parseFloat(noteStyle.paddingBottom)) / parseFloat(noteStyle.lineHeight)
        }
      })()
    JS

    expect(layout.fetch("detailGap")).to be >= 20
    expect((layout.fetch("cashTop") - layout.fetch("reserveTop")).abs).to be < 1
    expect(layout.fetch("yearUnitWidth")).to be >= 68
    expect(layout.fetch("noteGap")).to be >= 18
    expect(layout.fetch("noteLines")).to be < 1.5
  end

  it "keeps payment events simple and reveals advanced timing fields on demand" do
    visit purchase_calculator_path(example: 1)
    click_button "03 График на плащанията"
    expect(page).to have_text("Подреди плащанията по етапи и провери кога са нужни собствени средства или ипотека")

    disclosure_spacing = page.evaluate_script(<<~JS)
      (() => {
        const disclosures = Array.from(document.querySelectorAll('.calculator-disclosure'))
        const reservation = disclosures.find((details) => details.querySelector('summary')?.textContent.includes('Резервационно плащане'))
        const mortgageDraws = disclosures.find((details) => details.querySelector('summary')?.textContent.includes('Усвояване на кредита на части'))
        const warning = document.querySelector('.calculator-inline-warning')
        const openContent = reservation.querySelector('.calculator-fields')

        return {
          openGap: openContent.getBoundingClientRect().top - reservation.querySelector('summary').getBoundingClientRect().bottom,
          followingGap: warning.getBoundingClientRect().top - mortgageDraws.getBoundingClientRect().bottom
        }
      })()
    JS
    expect(disclosure_spacing.values).to all(be_within(1).of(12))

    first_row = all(".schedule-row").first
    within(first_row) do
      expect(page).to have_field("Събитие", with: "Предварителен договор")
      expect(find_field("Как се определя сумата?", visible: :all).value).to eq("percentage")
      expect(page).to have_css(".select-menu__trigger", text: "Процент от цената")
      expect(page).to have_field("Процент от цената", with: "10.0")
      expect(page).to have_no_text("Ключ:")
      expect(page).to have_no_field("Дата (по избор)")
    end
    event_field = first_row.find_field("Събитие")
    expect(event_field["role"]).to eq("combobox")
    expect(event_field["list"]).to be_nil
    event_field.click
    combobox_menu = find(".combobox-options:not([hidden])")
    expect(combobox_menu).to have_css(".select-menu__option", text: "Акт 14")
    page.execute_script("arguments[0].dispatchEvent(new Event('scroll'))", combobox_menu)
    expect(page).to have_css(".combobox-options:not([hidden])")
    page.execute_script("window.dispatchEvent(new Event('scroll'))")
    expect(page).to have_no_css(".combobox-options:not([hidden])")
    event_field.click
    event_field.send_keys(:escape)
    expect(page).to have_no_css(".combobox-options:not([hidden])")

    choose_custom_select("Как се определя сумата?", "Фиксирана сума", within: first_row)
    within(first_row) do
      expect(page).to have_field("Сума")
      expect(page).to have_no_field("Процент от цената")

      find("summary", text: "Допълнителни настройки").click
      expect(page).to have_field("Дата (по избор)")
      expect(page).to have_field("Вече платено")
    end

    expect(page).to have_select("Към кое плащане се приспада?", with_options: [ "Предварителен договор" ], visible: :all)
    expect(page).to have_select("От кой момент можеш да използваш ипотечния кредит?", with_options: [ "Нотариално прехвърляне" ], visible: :all)
  end

  it "saves and resumes an example mortgage-purchase scenario" do
    visit purchase_calculator_path(example: 1)
    click_button "03 График на плащанията"
    find("summary", text: "Запази сметката").click
    expect(page).to have_text("Черновата се пази само в текущия раздел")
    save_field = find_field("Име на сметката")
    save_button = find_button("Запази тази сметка")
    expect((save_field.rect.height - save_button.rect.height).abs).to be < 1
    fill_in "Име на сметката", with: "Системен сценарий"
    click_button "Запази тази сметка"

    expect(page).to have_text("Запазена сметка")
    expect(page).to have_field("Преименувай", with: "Системен сценарий")
    expect(page).to have_button("Започни отначало")
    expect(page.find("#purchase-calculator")["data-calculator-form-draft-enabled-value"]).to eq("false")
    expect(BudgetScenario.order(:created_at).last.validated_inputs.dig("loan", "principal_cents")).to eq(24_000_000)

    expect {
      accept_confirm { click_button "Започни отначало" }
      expect(page).to have_current_path(purchase_calculator_path)
      expect(page).to have_field("Цена по сделката", with: "")
    }.not_to change(BudgetScenario, :count)
  end

  it "restores an unsaved purchase draft after a refresh in the same tab" do
    expect {
      visit purchase_calculator_path
      page.execute_script("window.sessionStorage.clear()")
      page.refresh
      fill_in "Цена по сделката", with: "245000"
      find(".calculator-panel__heading").click
      expect(page).to have_text("245 000,00 €")
      choose_custom_select("Община", "Друга община")
      fill_in "Ръчно въведена местна ставка", with: "2,7"

      breakdown_summary = find("summary", text: "Разбивка на цената", exact_text: false)
      breakdown_summary.click
      find('input[name="calculator[components][garage][amount]"]').set("15000")

      click_button "03 График на плащанията"
      choose_custom_select("Примерен график", "10% / 10% / 80%")
      first_schedule_row = first(".schedule-row")
      first_schedule_row.find("input[data-field='label']").set("Персонализиран етап")
      first_schedule_row.find("summary", text: "Допълнителни настройки").click

      page.execute_script("window.dispatchEvent(new Event('pagehide'))")
      expect(page.evaluate_script("sessionStorage.getItem('mesto:calculator-draft:purchase:v1')")).to be_present

      page.refresh

      expect(page).to have_field("Цена по сделката", with: "245000", visible: :all)
      expect(page).to have_field("Ръчно въведена местна ставка", with: "2,7", visible: :all)
      expect(find('input[name="calculator[components][garage][amount]"]', visible: :all).value).to eq("15000")
      expect(page).to have_css("[data-calculator-tabs-target='tab'][data-section='schedule'][aria-selected='true']")
      expect(page).to have_css(".schedule-row", count: 3)
      expect(first(".schedule-row").find("input[data-field='label']").value).to eq("Персонализиран етап")
      expect(page.evaluate_script("arguments[0].open", first(".schedule-row").find(".schedule-row__advanced"))).to be(true)
      restored_breakdown = find("summary", text: "Разбивка на цената", exact_text: false, visible: :all).find(:xpath, "..", visible: :all)
      expect(page.evaluate_script("arguments[0].open", restored_breakdown)).to be(true)
      expect(page).to have_text("245 000,00 €")
      expect(page).to have_button("Започни отначало")

      accept_confirm { click_button "Започни отначало" }
      expect(page).to have_current_path(purchase_calculator_path)
      expect(page).to have_field("Цена по сделката", with: "")
      expect(page.evaluate_script("sessionStorage.getItem('mesto:calculator-draft:purchase:v1')")).to be_nil
    }.not_to change(BudgetScenario, :count)
  end

  it "keeps an explicit example separate from the anonymous draft" do
    visit purchase_calculator_path
    page.execute_script("window.sessionStorage.clear()")
    page.refresh
    fill_in "Цена по сделката", with: "123456"
    page.execute_script("window.dispatchEvent(new Event('pagehide'))")

    visit purchase_calculator_path(example: 1)

    expect(page).to have_field("Цена по сделката", with: "300000")
    expect(page.find("#purchase-calculator")["data-calculator-form-draft-enabled-value"]).to eq("false")
    expect(page).to have_button("Започни отначало")

    accept_confirm { click_button "Започни отначало" }
    expect(page).to have_current_path(purchase_calculator_path)
    expect(page).to have_field("Цена по сделката", with: "")
    expect(page.evaluate_script("sessionStorage.getItem('mesto:calculator-draft:purchase:v1')")).to be_nil
  end

  it "restores an unsaved mortgage draft after a refresh in the same tab" do
    visit mortgage_calculator_path
    page.execute_script("window.sessionStorage.clear()")
    page.refresh
    fill_in "Размер на кредита", with: "180000"
    fill_in "Годишна номинална лихва", with: "3,25"
    fill_in "Срок", with: "25"
    page.execute_script("window.dispatchEvent(new Event('pagehide'))")

    page.refresh

    expect(page).to have_field("Размер на кредита", with: "180000")
    expect(page).to have_field("Годишна номинална лихва", with: "3,25")
    expect(page).to have_field("Срок", with: "25")
    expect(page).to have_text("877,17 €")
    expect(page).to have_button("Започни отначало")
  end

  it "offers an optional owned-journey attachment without changing education progress" do
    visit my_mesto_path
    find("label", text: "Ново строителство").click
    select "Само разглеждам и се подготвям", from: "buyer_journey_buyer_stage"
    fill_in "Име на варианта (по избор)", with: "Тест план"
    click_button "Създай моя план"
    expect(page).to have_text("Твоята подготовка за покупка")
    journey = BuyerJourney.order(:created_at).last

    visit purchase_calculator_path(example: 1)
    click_button "03 График на плащанията"
    find("summary", text: "Запази сметката").click
    choose_custom_select("Свържи с личен план (по избор)", "Тест план")
    fill_in "Име на сметката", with: "Свързан сценарий"
    click_button "Запази тази сметка"

    expect(page).to have_current_path(%r{\A/kalkulator/scenarii/[0-9a-f-]+\z})
    expect(page).to have_text("Свързан личен план: Тест план")
    expect(journey.journey_item_progresses).to be_empty
  end

  it "enters the standalone calculator directly from existing education" do
    visit buying_guide_path
    click_link "Отвори калкулатора за покупка"
    expect(page).to have_current_path(purchase_calculator_path)
    expect(page).to have_field("Цена по сделката", with: "")
  end

  it "prevents an older recalculation response from replacing a newer one" do
    visit purchase_calculator_path
    prevented = page.evaluate_script(<<~JS)
      (() => {
        const sequence = document.querySelector('[data-calculator-form-target="sequence"]')
        sequence.value = "5"
        const frame = document.getElementById("calculator-results")
        const incoming = document.createElement("turbo-frame")
        incoming.dataset.sequence = "4"
        const event = new CustomEvent("turbo:before-frame-render", {
          bubbles: true, cancelable: true, detail: { newFrame: incoming }
        })
        return !frame.dispatchEvent(event)
      })()
    JS
    expect(prevented).to be(true)
  end

  it "uses the branded listbox on desktop and keeps the native select as the form value" do
    visit purchase_calculator_path

    municipality = find_field("Община", visible: :all)
    trigger = municipality.find(:xpath, "..").find(".select-menu__trigger")
    expect(municipality["aria-hidden"]).to eq("true")
    expect(trigger).to have_text("Столична община")

    trigger.click
    expect(page).to have_css('.select-menu__options:not([hidden]) [role="option"]', text: "Друга община")
    other_municipality = find('.select-menu__options:not([hidden]) [role="option"]', text: "Друга община", exact_text: true)
    other_municipality.hover
    expect(page.evaluate_script("getComputedStyle(arguments[0]).backgroundColor", other_municipality)).to eq("rgb(246, 248, 244)")
    other_municipality.click

    expect(municipality.value).to eq("other")
    expect(page).to have_field("Ръчно въведена местна ставка")

    trigger.click
    selected_option = find('.select-menu__options:not([hidden]) [role="option"][aria-selected="true"]')
    selected_option.send_keys(:escape)
    expect(page).to have_no_css('.select-menu__options:not([hidden])')
    expect(page.evaluate_script("document.activeElement === document.querySelector('#calculator_municipality').parentElement.querySelector('.select-menu__trigger')")).to be(true)

    trigger.click
    find('.select-menu__options:not([hidden]) [role="option"][aria-selected="true"]').send_keys(:tab)
    expect(page.evaluate_script("document.activeElement === document.querySelector('#calculator_manual_local_tax_rate')")).to be(true)
  end

  it "makes collapsed calculator sections visibly expandable" do
    visit purchase_calculator_path

    breakdown_summary = find("summary", text: "Разбивка на цената", exact_text: false)
    breakdown = breakdown_summary.find(:xpath, "..")
    marker = page.evaluate_script(<<~JS, breakdown_summary)
      (() => {
        const style = getComputedStyle(arguments[0], "::after")
        return { width: style.width, height: style.height, backgroundImage: style.backgroundImage }
      })()
    JS

    expect(marker.fetch("width")).to eq("30px")
    expect(marker.fetch("height")).to eq("30px")
    expect(marker.fetch("backgroundImage")).not_to eq("none")
    expect(page.evaluate_script("arguments[0].open", breakdown)).to be(false)

    breakdown_summary.hover
    expect(page.evaluate_script("getComputedStyle(arguments[0]).backgroundColor", breakdown_summary)).to eq("rgba(0, 0, 0, 0)")

    breakdown_summary.click
    expect(page.evaluate_script("arguments[0].open", breakdown)).to be(true)
    expect(page).to have_field("calculator[components][garage][amount]")
  end

  it "keeps long desktop results in the normal page flow" do
    page.current_window.resize_to(1440, 900)
    visit purchase_calculator_path(example: 1)

    summary = find(".calculator-summary")
    layout = page.evaluate_script(<<~JS, summary)
      (() => {
        const element = arguments[0]
        const style = getComputedStyle(element)
        return {
          position: style.position,
          overflowY: style.overflowY,
          maxHeight: style.maxHeight,
          paddingBottom: style.paddingBottom,
          formTop: document.querySelector(".calculator-form").getBoundingClientRect().top,
          summaryTop: element.getBoundingClientRect().top
        }
      })()
    JS

    expect(page).to have_text("ЗА УТОЧНЯВАНЕ")
    expect(page).to have_text("Какво остава да уточниш")
    warning_details = find(".summary-warnings")
    expect(page.evaluate_script("arguments[0].open", warning_details)).to be(false)
    expect(warning_details).to have_text(/\d+ уточнени(?:е|я)/)
    warning_summary = warning_details.find("summary")
    warning_summary.hover
    expect(page.evaluate_script("getComputedStyle(arguments[0]).backgroundColor", warning_summary)).to eq("rgb(244, 240, 232)")
    expect(layout.fetch("position")).to eq("sticky")
    expect(layout.fetch("overflowY")).to eq("visible")
    expect(layout.fetch("maxHeight")).to eq("none")
    expect(layout.fetch("paddingBottom")).to eq("0px")
    expect((layout.fetch("formTop") - layout.fetch("summaryTop")).abs).to be < 1

    warning_summary.click
    expect(page.evaluate_script("arguments[0].open", warning_details)).to be(true)
    expect(warning_details).to have_css("li", minimum: 1, visible: true)
    warning_alignment = page.evaluate_script(<<~JS, warning_details)
      (() => {
        const details = arguments[0]
        return {
          titleLeft: details.querySelector("summary strong").getBoundingClientRect().left,
          noteLeft: details.querySelector("li").getBoundingClientRect().left
        }
      })()
    JS
    expect((warning_alignment.fetch("titleLeft") - warning_alignment.fetch("noteLeft")).abs).to be < 1
  end

  it "presents other costs as guided cards without a horizontal data grid" do
    visit purchase_calculator_path(example: 1)

    expect(page).to have_text("Местният данък, таксата за вписване и основната нотариална такса се изчисляват автоматично")
    expect(page.evaluate_script("document.querySelector('.cost-editor').scrollWidth <= document.querySelector('.cost-editor').clientWidth")).to be(true)
    expect(page).to have_css(".cost-editor__group", count: 4)

    lawyer = find(".cost-editor__item", text: "Адвокат")
    within(lawyer) do
      expect(page).to have_text("Договорена сума за правен преглед")
      expect(page).to have_no_field("Сума от офертата")
      check "cost_lawyer_included"
      expect(page).to have_text("Добавено към сметката")
      expect(page).to have_field("Сума от офертата")
    end

    choose_custom_select("Каква информация имаш?", "Процент", within: lawyer)
    within(lawyer) do
      expect(page).to have_field("Процент")
      expect(page).to have_no_field("Сума от офертата")
    end

    choose_custom_select("Каква информация имаш?", "Още не знам сумата", within: lawyer)
    within(lawyer) do
      expect(page).to have_text("Оставяме сумата неизвестна")
      find("summary", text: "Допълнителни настройки").click
      expect(page).to have_text(/Как е посочена сумата спрямо ДДС\?/i)
      expect(page).to have_text(/Кога ще го платиш\?/i)
      expect(page).to have_text(/Колко вече е платено\?/i)
    end
  end

  it "restores a mobile draft through the native form controls" do
    page.current_window.resize_to(390, 844)
    visit purchase_calculator_path
    page.execute_script("window.sessionStorage.clear()")
    page.refresh

    fill_in "Цена по сделката", with: "210000"
    select "Друга община", from: "Община"
    fill_in "Ръчно въведена местна ставка", with: "2,4"
    page.execute_script("window.dispatchEvent(new Event('pagehide'))")

    page.refresh

    expect(page).to have_field("Цена по сделката", with: "210000")
    expect(page).to have_select("Община", selected: "Друга община")
    expect(page).to have_field("Ръчно въведена местна ставка", with: "2,4")
    expect(page).to have_text("210 000,00 €")
  end

  it "keeps the mobile layout stacked without a fixed summary or page-level overflow" do
    page.current_window.resize_to(390, 844)
    visit purchase_calculator_path(example: 1)

    expect(page.evaluate_script("getComputedStyle(document.querySelector('.calculator-summary')).position")).to eq("static")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    expect(page).to have_select("Община")
    expect(page).to have_no_css("#purchase-calculator .select-menu__trigger")
    expect(page.evaluate_script("document.querySelector('.cost-editor').scrollWidth <= document.querySelector('.cost-editor').clientWidth")).to be(true)
    native_style = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector('#calculator_municipality'))
        return { appearance: style.appearance, backgroundImage: style.backgroundImage }
      })()
    JS
    expect(native_style).to eq("appearance" => "auto", "backgroundImage" => "none")
    click_button "03 График на плащанията"
    expect(page).to have_text(/Примерен график/i)
    mobile_event_field = first(".schedule-row").find_field("Събитие")
    expect(mobile_event_field["list"]).to eq("schedule-event-labels")
    expect(mobile_event_field["role"]).to be_nil
  end
end
