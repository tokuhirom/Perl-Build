# How to fatpack perl-build

There are 3 options:

### Docker

```
docker build -t perl-build .
docker run -v /path/to/local/Perl-Build:/perl-build perl-build
```

### Vagrant

In fact, this uses docker internally:

```
vagrant up --provision
```

### Your local environment

Make sure you have App::cpm, App::FatPacker::Simple, Carton. If not, install them first:

```
cpanm -nq App::cpm App::FatPacker::Simple Carton
```

Then:
```
perl fatpack.pl
```

## Hint

### How do we update dependencies?

Execute `fatpack.pl` with `--update` option, so that `cpanfile.snapshot` will be updated.
