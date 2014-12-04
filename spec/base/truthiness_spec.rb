
RSpec.describe "Language", "truthiness" do
  TRUTHY_VALUES = [ 'true', '0', '1', '"Hello"', '""', '{$}','[$]', '{}', '[]' ]
  FALSEY_VALUES = [ 'nil', 'undefined', 'false' ]

  it "has working truthy" do
    expect(
      TRUTHY_VALUES.map { |x| "(print (truthy #{x}))" }.join
    ).to have_output(['true'] * TRUTHY_VALUES.length)

    expect(
      FALSEY_VALUES.map { |x| "(print (truthy #{x}))" }.join
    ).to have_output(['false'] * FALSEY_VALUES.length)
  end

  it "has working falsey" do
    expect(
      TRUTHY_VALUES.map { |x| "(print (falsey #{x}))" }.join
    ).to have_output(['false'] * TRUTHY_VALUES.length)

    expect(
      FALSEY_VALUES.map { |x| "(print (falsey #{x}))" }.join
    ).to have_output(['true'] * FALSEY_VALUES.length)
  end
end

