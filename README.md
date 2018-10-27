# Message broker for Event Data Services

<!-- [![Identifier](https://img.shields.io/badge/doi-10.5438%2Ft1jg--hvhn-fca709.svg)](https://doi.org/10.5438/t1jg-hvhn) -->
[![Build Status](https://travis-ci.org/datacite/levriero.svg?branch=master)](https://travis-ci.org/datacite/levriero) [![Code Climate](https://codeclimate.com/github/datacite/levriero/badges/gpa.svg)](https://codeclimate.com/github/datacite/levriero) [![Test Coverage](https://codeclimate.com/github/datacite/levriero/badges/coverage.svg)](https://codeclimate.com/github/datacite/levriero/coverage)

Levriero runs agents for the Crossref/DataCite Event Data service.

![](http://www.ioeilmioanimale.it/wp-content/uploads/2017/09/italian-greyhound-nature-523160830.jpg)

## Installation

Using Docker.

```
docker run -p 8040:80 datacite/levriero
```

You can now point your browser to `http://localhost:8040` and use the application.


## Development

One can generate a user with writing access from the rails console:

```
~/webapp# bin/rails c
2.4.1 :001 > User.generate_token(exp: 365)

```

We use Rspec for unit and acceptance testing:

```
bundle exec rspec
```

Follow along via [Github Issues](https://github.com/datacite/levriero/issues).


### Note on Patches/Pull Requests

* Fork the project
* Write tests for your new feature or a test that reproduces a bug
* Implement your feature or make a bug fix
* Do not mess with Rakefile, version or history
* Commit, push and make a pull request. Bonus points for topical branches.

## License
**levriero** is released under the [MIT License](https://github.com/datacite/levriero/blob/master/LICENSE).
