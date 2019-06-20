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
        reverse => {
            summary => 'Decrement instead of increment',
            schema => 'true*',
            cmdline_aliases => {r=>{}},
        },
        business => {
            summary => 'Only list business days (Mon-Fri), '.
                'or non-business days',
            schema => ['bool*'],
            tags => ['category:filtering'],
        },
        business6 => {
            summary => 'Only list business days (Mon-Sat), '.
                'or non-business days',
            schema => ['bool*'],
            tags => ['category:filtering'],
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
            summary => 'Generate "infinite" dates from today',
            src => '[[prog]]',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'Generate dates from 2015-01-01 to 2015-01-31',
            src => '[[prog]] 2015-01-01 2015-01-31',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate dates from yesterday to 2 weeks from now',
            src => '[[prog]] yesterday "2 weeks from now"',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate dates from 2015-01-31 to 2015-01-01 (reverse)',
            src => '[[prog]] 2015-01-31 2015-01-01 -r',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 5,
        },
        {
            summary => 'Generate "infinite" dates from 2015-01-01 (reverse)',
            src => '[[prog]] 2015-01-01 -r',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'Generate 10 dates from 2015-01-01',
            src => '[[prog]] 2015-01-01 -n 10',
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
            summary => 'Generate first 20 business days (Mon-Fri) after 2015-01-01',
            src => '[[prog]] 2015-01-01 --business -n 20 -f "%Y-%m-%d(%a)"',
            src_plang => 'bash',
            'x.doc.max_result_lines' => 10,
        },
        {
            summary => 'Generate first 5 non-business days (Sat-Sun) after 2015-01-01',
            src => '[[prog]] 2015-01-01 --no-business -n 5',
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

    $args{from} //= DateTime->today;
    $args{increment} //= DateTime::Duration->new(days=>1);
    my $reverse = $args{reverse};

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
        if (defined $args{business}) {
            my $dow = $dt->day_of_week;
            if ($args{business}) {
                return 0 if $dow >= 6;
            } else {
                return 0 if $dow <  6;
            }
        }
        if (defined $args{business6}) {
            my $dow = $dt->day_of_week;
            if ($args{business6}) {
                return 0 if $dow >= 7;
            } else {
                return 0 if $dow <  7;
            }
        }
        1;
    };

    if (defined $args{to} || defined $args{limit}) {
        my @res;
        push @res, $args{header} if $args{header};
        my $dt = $args{from}->clone;
        while (1) {
            if (defined $args{to}) {
                last if  $reverse && DateTime->compare($dt, $args{to}) <  0;
                last if !$reverse && DateTime->compare($dt, $args{to}) >= 0;
            }
            push @res, $strp->format_datetime($dt) if $code_filter->($dt);
            last if defined($args{limit}) && @res >= $args{limit};
            $dt = $reverse ? $dt - $args{increment} : $dt + $args{increment};
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
            $next_dt = $reverse ?
                $dt - $args{increment} : $dt + $args{increment};
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
