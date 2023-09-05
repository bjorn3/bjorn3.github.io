# docker build . --tag blog && docker run -it -v .:/usr/src/app -p 4000 --rm --network=host blog

FROM docker.io/ruby:bookworm

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN bundle install

#RUN cat Gemfile.lock

CMD bundle exec jekyll serve
