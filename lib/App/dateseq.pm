package App::dateseq;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{dateseq} = {
    v => 1.1,
    summary => 'Generate a sequence of dates',
    description => <<'_',

This utility is similar to Unix <prog:seq> command, except that it generates a
sequence of dates.

_
    args_rels => {
        'choose_one&' => [
            [qw/business business6/],
        ],
    },
    args => {
        from => {
            summary => 'Starting date',
            schema => ['date*', {
                'x.perl.coerce_to' => 'DateTime',
                'x.perl.coerce_rules' => ['str_alami_en'],
            }],
            req => 1,
            pos => 0,
        },
        to => {
            summary => 'End date, if not specified will generate an infinite* stream of dates',
            schema => ['date*', {
                'x.perl.coerce_to' => 'DateTime',
                'x.perl.coerce_rules' => ['str_alami_en'],
            }],
            pos => 1,
        },
        increment => {
            schema => ['duration*', {
                'x.perl.coerce_to' => 'DateTime::Duration',
            }],
            cmdline_aliases => {i=>{}},
            pos => 2,
        },
        business => {
            summary => 'Only list business days (Mon-Fri)',
            schema => ['bool*', is=>1],
        },
        business6 => {
            summary => 'Only list business days (Mon-Sat)',
            schema => ['bool*', is=>1],
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
            summary => 'strftime() format for each date',
            description => <<'_',

Default is `%Y-%m-%d`, unless when hour/minute/second is specified, then it is
`%Y-%m-%dT%H:%M:%S`.

_
            schema => ['str*'],
            cmdline_aliases => {f=>{}},
        },
    },
    examples => [
        {
            summary => 'Generate dates from 2015-01-01 to 2015-01-31',
            src => '[[prog]] 2015-01-01 2015-01-31',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate dates from 2015-01-01 to today',
            src => '[[prog]] 2015-01-01 today',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate dates with increment of 3 days',
            src => '[[prog]] 2015-01-01 2015-01-31 -i P3D',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate a CSV data',
            src => '[[prog]] 2010-01-01 2015-01-31 -f "%Y,%m,%d" --header "year,month,day"',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate periods (YYYY-MM)',
            src => '[[prog]] 2010-01-01 2015-12-31 -i P1M -f "%Y-%m"',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'List non-holidays in 2015 (using Indonesian holidays)',
            src => 'setop --diff <([[prog]] 2015-01-01 2015-12-31) <(list-id-holidays --year 2015)',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'List non-holidays business days in 2015 (using Indonesian holidays)',
            src => 'setop --diff <([[prog]] 2015-01-01 2015-12-31 --business) <(list-id-holidays --year 2015)',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'Use with fsql',
            src => q{[[prog]] 2010-01-01 2015-12-01 -f "%Y,%m" -i P1M --header "year,month" | fsql --add-csv - --add-csv data.csv -F YEAR -F MONTH 'SELECT year, month, data1 FROM stdin WHERE YEAR(data.date)=year AND MONTH(data.date)=month'},
            src_plang => 'bash',
            'x.doc.show_result' => 0,
        },
    ],
};
sub dateseq {
    require DateTime::Duration;
    require DateTime::Format::Strptime;

    my %args = @_;

    $args{increment} //= DateTime::Duration->new(days=>1);

    my $fmt  = $args{date_format} // do {
        my $has_hms;
        {
            if ($args{from}->hour || $args{from}->minute || $args{from}->second) {
                $has_hms++; last;
            }
            if (defined($args{to}) &&
                    ($args{to}->hour || $args{to}->minute || $args{to}->second)) {
                $has_hms++; last;
            }
            if ($args{increment}->hours || $args{increment}->minutes || $args{increment}->seconds) {
                $has_hms++; last;
            }
        }
        $has_hms ? '%Y-%m-%dT%H:%M:%S' : '%Y-%m-%d';
    };
    my $strp = DateTime::Format::Strptime->new(
        pattern => $fmt,
    );

    my $code_filter = sub {
        my $dt = shift;
        if ($args{business}) {
            my $dow = $dt->day_of_week;
            return 0 if $dow >= 6;
        }
        if ($args{business6}) {
            my $dow = $dt->day_of_week;
            return 0 if $dow >= 7;
        }
        1;
    };

    if (defined $args{to}) {
        my @res;
        push @res, $args{header} if $args{header};
        my $dt = $args{from}->clone;
        while (DateTime->compare($dt, $args{to}) <= 0) {
            push @res, $strp->format_datetime($dt) if $code_filter->($dt);
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
        my $func0 = sub {
            #return undef if $finish;
            $dt = $next_dt if $j++ > 0;
            return $args{header} if $j == 0 && $args{header};
            $next_dt = $dt + $args{increment};
            #$finish = 1 if ...
            return $dt;
        };
        my $filtered_func = sub {
            while (1) {
                my $dt = $func0->();
                return undef unless defined $dt;
                last if $code_filter->($dt);
            }
            $strp->format_datetime($dt);
        };
        return [200, "OK", $filtered_func, {schema=>'str*', stream=>1}];
    }
}

1;
# ABSTRACT:
