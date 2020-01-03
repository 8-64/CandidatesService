# Let it be fast and modern
FROM perl:5.30

MAINTAINER Vasyl Kupchenko

ADD . /opt/MyService
WORKDIR /opt/MyService
RUN ls -ahl

# Version check
RUN perl -E "$^V gt v5.23 or exit 1"

# In 5.30 image there is also Perl 5.28. Wonderful.
RUN perl -E "exit 1 if (qx[which perl] ne q[/usr/bin/perl])" || \
perl -p -i -E 'BEGIN{ chomp($main::r = qx[which perl]) } s:/usr/bin/perl:$r:g' $( find ./ -name *.psgi -o -name *.t -o -name *.pl )

# It fails by default. Wonderful again.
RUN cpanm --force Time::Zone
# Faster installer
RUN cpanm App::cpm
# Even faster installer
RUN cpm install --global Plack DBI DBD::SQLite YAML Thrall Gazelle Class::Accessor::Fast Plack::Middleware::Debug Regexp::Common IO::Socket::SSL

# Test it
RUN prove

EXPOSE 8080

ENTRYPOINT perl bin/candidates.psgi
