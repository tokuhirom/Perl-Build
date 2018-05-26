FROM perl:5.26.1

RUN curl --compressed -sSL https://git.io/cpm -o /tmp/cpm
RUN perl /tmp/cpm install -g App::cpm App::FatPacker::Simple Carton
CMD ["perl", "/perl-build/author/fatpack.pl"]
