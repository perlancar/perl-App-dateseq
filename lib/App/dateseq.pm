package App::dateseq;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{seq} = {
    v => 1.1,
    summary => 'Generate a sequence of dates',
    description => <<'_',

This utility is similar to Unix `seq` command, except that it generates a
sequence of dates.

_
    #args_rels => {
    #},
    args => {
        from => {
            schema => 'date*',
            req => 1,
            pos => 0,
        },
        to => {
            schema => 'date*',
            pos => 1,
        },
        increment => {
            schema => 'duration*',
            cmdline_aliases => {i=>{}},
            pos => 2,
        },
        header => {
            summary => 'Add a header row',
            schema => 'str*',
        },
        limit => {
            summary => 'Only generate a certain amount of numbers',
            schema => ['int*', min=>1],
            cmdline_aliases => {n=>{}},
        },
        date_format => {
            summary => 'strptime() format for each date',
            schema => ['str*'],
            cmdline_aliases => {f=>{}},
        },
    },
    examples => [
        {
            summary => 'Generate dates from 2015-01-01 to 2015-03-31',
            src => 'dateseq 2015-01-01 2015-03-31',
            src_plang => 'bash',
        },
        {
            summary => 'Generate dates with increment of 3 days',
            src => 'dateseq 2015-01-01 2015-03-31 -i P3D',
            src_plang => 'bash',
        },
        {
            summary => 'Generate dates with increment of 3 days',
            src => 'dateseq 2015-01-01 2015-03-31 -i P3D',
            src_plang => 'bash',
        },
        {
            summary => 'Format dates, use with fsql',
            src => q[dateseq 2010-01-01 2015-12-01 -f "%Y,%m" -i P1M --header "year,month" | fsql --add-csv - --add-csv data.csv -F YEAR -F MONTH 'SELECT year, month, data1 FROM stdin WHERE YEAR(data.date)=year AND MONTH(data.date)=month'],
            src_plang => 'bash',
        },
    ],
};
sub seq {
    require DateTime::Format::Strptime;

    my %args = @_;

    my $fmt  = $args{date_format} // '%Y-%m-%d';
    my $strp = DateTime::Format::Strptime->new(
        pattern => $fmt,
    );

    if (defined $args{to}) {
        my @res;
        push @res, $args{header} if $args{header};
        my $dt = $args{from}->clone;
        while (DateTime->compare($dt, $args{to}) <= 0) {
            push @res, $strp->format_datetime($dt);
            last if defined($args{limit}) && @res >= $args{limit};
            $dt = $dt + $args{increment};
        }
        return [200, "OK", \@res];
    } else {
        # stream
        my $dt = $args{from}->clone;
        my $j  = $args{header} ? -1 : 0;
        my $next_dt;
        #my $finish;
        my $func = sub {
            #return undef if $finish;
            $dt = $next_dt if $j++ > 0;
            return $args{header} if $j == 0 && $args{header};
            $next_dt = $dt + $args{increment};
            #$finish = 1 if ...
            return $strp->format_datetime($dt);
        };
        return [200, "OK", $func, {stream=>1}];
    }
}

1;
# ABSTRACT:
