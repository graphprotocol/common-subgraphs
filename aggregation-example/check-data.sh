#! /bin/bash

# Check the data in the subgraph for anomalies
# Use by running
#    check-data.sh sgdNNN | psql -qX <database connection>
#
# All queries should return 0 as the count; if they don't there's something
# wrong with the data.

expand() {
    printf "$1;\n" "$2" "hour"
    printf "$1;\n" "$2" "day"
}

# There's something funky with the first aggregation where max is one more
# than last
read -d '' -r max_last <<'EOF'
select count(*) as max_is_not_last
  from %s.stats_%s
 where max != last
   and first > 1
EOF

read -d '' -r min_first <<'EOF'
select count(*) as min_is_not_first
  from %s.stats_%s
 where min != first
EOF

read -d '' -r sum_check <<'EOF'
select count(*) as sum_not_correct
  from %s.stats_%s
 where sum != (last - first + 1)::numeric*(last + first)::numeric/2
   and first > 1
EOF

# The last ingested block will cause the count to be 1
read -d '' -r gaps_hour <<'EOF'
select count(*) - 1 as gaps_hour
  from %s.stats_hour s1
 where timestamp > 0 -- first rollup has funky timestamp
   and not exists (
      select 1 from %s.stats_hour s2
       where s1.timestamp = s2.timestamp - 3600)
EOF
read -d '' -r gaps_day <<'EOF'
select count(*) - 1 as gaps_day
  from %s.stats_day s1
 where timestamp > 0 -- first rollup has funky timestamp
   and not exists (
      select 1 from %s.stats_day s2
       where s1.timestamp = s2.timestamp - 86400)
EOF

expand "$max_last" $1
expand "$min_first" $1
expand "$sum_check" $1
printf "$gaps_hour;\n" $1 $1
printf "$gaps_day;\n" $1 $1
