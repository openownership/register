files_to_watch = Dir
  .glob('.env*')
  .concat(
    %w[
      .ruby-version
      .rbenv-vars
      tmp/restart.txt
      tmp/caching-dev.txt
    ],
  )

files_to_watch.each { |path| Spring.watch(path) }
