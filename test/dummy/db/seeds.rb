
template = {
  :array    => [1, 'string', true],
  :boolean  => true,
  :number   => 1,
  :string   => 'string',
  :folder   => {
    :array    => [1, 'string', true],
    :boolean  => true,
    :number   => 1,
    :string   => 'string',
  }
}

puts "Seeding dummy database with template: #{template.inspect}"
Registry::Entry.root(Rails.env).merge(template)
