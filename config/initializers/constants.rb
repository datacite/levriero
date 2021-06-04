RESCUABLE_EXCEPTIONS = [CanCan::AccessDenied,
                        CanCan::AuthorizationNotPerformed,
                        JWT::VerificationError,
                        JSON::ParserError,
                        # AbstractController::ActionNotFound,
                        ActionController::RoutingError,
                        ActionController::ParameterMissing,
                        ActionController::UnpermittedParameters,
                        NoMethodError].freeze

# Format used for DOI validation
# The prefix is 10.x where x is 4-5 digits. The suffix can be anything, but can"t be left off
DOI_FORMAT = %r(\A10\.\d{4,5}/.+).freeze

# Format used for URL validation
URL_FORMAT = %r(\A(http|https|ftp)://[a-z0-9]+([\-.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?/.*)?\z).freeze

# Form queue options
QUEUE_OPTIONS = ["high", "default", "low"].freeze

# Version of ORCID API
ORCID_VERSION = "1.2".freeze

# ORCID schema
ORCID_SCHEMA = "https://raw.githubusercontent.com/ORCID/ORCID-Source/master/orcid-model/src/main/resources/orcid-message-1.2.xsd".freeze

# Version of DataCite API
DATACITE_VERSION = "4".freeze

# Date of DataCite Schema
DATACITE_SCHEMA_DATE = "2016-09-21".freeze

# regions used by countries gem
REGIONS = {
  "APAC" => "Asia and Pacific",
  "EMEA" => "Europe, Middle East and Africa",
  "AMER" => "Americas",
}.freeze
