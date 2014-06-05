# How to fatpack with docker
#
# docker build -t `whoami`/perl-build .
# docker run -v `pwd`/../:/perl-build `whoami`/perl-build
#

FROM jmmills/plenv-base:latest
RUN plenv install 5.8.5
RUN plenv global 5.8.5
ENV PLENV_VERSION 5.8.5
RUN curl -L http://cpanmin.us/ | plenv exec perl - -n ExtUtils::MakeMaker@6.66
RUN curl -L http://cpanmin.us/ | plenv exec perl - -n App::cpanminus
RUN curl -L http://cpanmin.us/ | plenv exec perl - -n Perl::Strip App::FatPacker
RUN plenv rehash
CMD bash -l -c 'cd /perl-build; cpanm -n --installdeps . ; bash author/fatpack.sh'

