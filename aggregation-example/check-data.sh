#! /bin/bash

# Check the data in the subgraph for anomalies
# Use by running
#    check-data.sh sgdNNN | psql -qX <database connection>
#
# All queries should return true; if they don't there's something wrong
# with the data.
#
# To abbreviate the output, you can pipe it into
#   rg -N -U --color=never '(\w+)\s+-+\s+(\w+)' -r '$1: $2'

sgd=$1

# Expand the query in $1 by substituting various values:
#  SGD  - the deployment 'sgdNNN' passed to the script
#  INTV - 'hour' and 'day'
#  DUR  - the duration of INTV in seconds
#  TBL  - all aggregation tables if TBL is present in the query
# Note that these substitutions are done for all possible combinations of
# INTV/DUR and TBL
expand() {
    query=${1//SGD/$sgd}
    if [[ "$query" =~ "INTV" ]]
    then
        for pair in hour:3600 day:86400
        do
            intv=${pair%:*}
            duration=${pair#*:}
            q=${query//INTV/$intv}
            q=${q//DUR/$duration}
            if [[ "$q" =~ "TBL" ]]
            then
                for tbl in stats group_1 group_2 group_3 groups
                do
                    echo "${q//TBL/$tbl};"
                done
            else
                echo "$q;"
            fi
        done
    else
        echo "$query;"
    fi
}

# Max and last must be the same
read -d '' -r max_last <<'EOF'
select count(*) = 0 as TBL_INTV_max_eq_last
  from SGD.TBL_INTV
 where max != last
EOF

# Min and first must be the same
read -d '' -r min_first <<'EOF'
select count(*) = 0 as TBL_INTV_min_eq_first
  from SGD.TBL_INTV
 where min != first
EOF

# The sum over block numbers must be correct
read -d '' -r sum_check <<'EOF'
select count(*) = 0 as stats_INTV_sum_correct
  from SGD.stats_INTV
 where sum != (last - first + 1)::numeric*(last + first)::numeric/2
   and first > 1
EOF

# The timestamps of all buckets are rounded to the beginning of the period
read -d '' -r bucket_timestamp <<'EOF'
select count(*) = 0 as TBL_INTV_bucket_timestamp
  from SGD.TBL_INTV
 where to_timestamp(timestamp)
    != date_trunc('INTV', to_timestamp(timestamp), 'utc')
EOF

# The timestamp of the min and max block for all buckets must be between
# the bucket's timestamp plus the bucket's duration
read -d '' -r block_timestamp <<'EOF'
select count(*) = 0 as TBL_INTV_timestamp
  from SGD.TBL_INTV s,
       SGD.block_time b
 where (b.number in (s.min, s.max))
   and (b.timestamp not between s.timestamp and s.timestamp + DUR)
EOF

# For group_3_hour, since we split the aggregations into 1000 buckets,
# there can only be one or two blocks in each bucket; if there are two,
# they must differ by 1000 blocks
read -d '' -r group3_count_min_max <<'EOF'
select count(*) = 0 as count_min_max
  from SGD.group_3_hour
 where (count = 1 and min != max)
    or (count = 2 and min + 1000 != max)
    or count > 2
EOF

# Same as previous for 'groups' instead of 'group_3'
read -d '' -r groups_count_min_max <<'EOF'
select count(*) = 0 as count_min_max
  from SGD.groups_hour
 where (count = 1 and min != max)
    or (count = 2 and min + 1000 != max)
    or count > 2
EOF

echo "\pset footer off"
expand "$max_last"
expand "$min_first"
expand "$sum_check"
expand "$bucket_timestamp"
expand "$block_timestamp"
expand "$group3_count_min_max"
