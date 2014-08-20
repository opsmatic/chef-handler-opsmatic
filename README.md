# Chef::Handler::Opsmatic

The chef-handler-opsmatic gem is a Chef report and exception handler

## Usage

The easiest way to install this handler in your Chef environment is with the `handler`
recipe in the [opsmatic-cookbook](https://github.com/opsmatic/opsmatic-cookbook) cookbook.

## Changelog

#### 0.0.9 (2014-08-19)
* adds support for generating a list of chef managed files for the Opsmatic agent to watch for changes
* adds sending chef-handler-opsmatic version in the user-agent string

## Contributing

1. Fork it ( https://github.com/[my-github-username]/chef-handler-opsmatic/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
