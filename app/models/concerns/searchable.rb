module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks

    name = model_name.collection.gsub(%r{\/}, '-')

    index_name "#{name}-#{Rails.env}"

    settings index: {
      analysis: {
        tokenizer: {
          ngram_repo_tokenizer: {
            type: 'nGram',
            min_gram: 2,
            max_gram: 3,
            token_chars: %w(
              letter
              digit
            )
          }
        },

        analyzer: {
          repo_ngram: {
            type: 'custom',
            tokenizer: 'ngram_repo_tokenizer',
            char_filter: %w(
              html_strip
            ),
            filter: %w(
              lowercase
            )
          }
        }
      }
    }
  end
end
