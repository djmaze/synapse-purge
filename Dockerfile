FROM ruby

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install -j 4 --without development

COPY *.rb ./

ENTRYPOINT ["/usr/src/app/synapse-purge.rb"]
