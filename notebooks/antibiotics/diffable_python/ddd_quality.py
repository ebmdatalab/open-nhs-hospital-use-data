# ---
# jupyter:
#   jupytext:
#     cell_metadata_filter: all
#     notebook_metadata_filter: all,-language_info
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.3.3
#   kernelspec:
#     display_name: Python 3
#     language: python
#     name: python3
# ---

import pandas as pd
from ebmdatalab import bq
from upsetplot import plot

# ## What's the overall record population?

# +
qry = """
select 
    True as vmp, 
    case when ddd.vpid is not null then True else False end as present_in_ddd_table, 
    case when ddd.DDD is not null then True else False end as with_ddd, 
    case when ddd.ATC is not null then True else False end as with_atc, 
    case when ddd.BNF is not null then True else False end as with_bnf_in_ddd

from `ebmdatalab.dmd.vmp` vmp
left join `ebmdatalab.dmd.ddd` ddd  on ddd.vpid = vmp.id
"""

df_bool = bq.cached_read(csv_path='ddd_boolean.csv',sql=qry)
# -

plot(df_bool.groupby(['vmp','present_in_ddd_table','with_ddd','with_atc','with_bnf_in_ddd']).size(), show_counts=True)

# ## How many ATC-route combinations have incomplete DDD records?
#
# DDD is defined by WHO at ATC + route of administration level.
#
# Some VMPs in NHSD-provided DDD table have NULL DDDs wheras other products with the same ATC and route of administration have populated DDDs.
#
# What is the extent of this problem?

qry = """
with cte as (
    select
        vmp.id as vmpid,
        ddd.ATC, 
        r.descr as route, 
        case when ddd.DDD is not null then True else False end as with_ddd, 
        case when ddd.BNF is not null then True else False end as with_bnf_in_ddd
    from `ebmdatalab.dmd.vmp` vmp
    join `ebmdatalab.dmd.ddd` ddd  on ddd.vpid = vmp.id
    join `ebmdatalab.dmd.droute` dr on vmp.id = dr.vmp
    join `ebmdatalab.dmd.route` r on dr.route = r.cd
    where ddd.ATC is not null )
,cte2 as (
    select 
        atc,
        route,
        count(distinct with_ddd) count_ddd,
        max(with_ddd) max_ddd,
        count(distinct with_bnf_in_ddd) count_bnf,
        max(with_bnf_in_ddd) max_bnf,
        count(distinct vmpid) as vmps
    from cte
    group by atc,route
)
select 
    atc,
    route,
    case when count_ddd=1 and max_ddd = True then 'full' when count_ddd>1 then 'partial' else 'none' end as ddd,
    case when count_bnf=1 and max_bnf = True then 'full' when count_bnf>1 then 'partial' else 'none' end as bnf,
    vmps
from cte2 
"""
df_atcroute = bq.cached_read(csv_path='ddd_atcroute.csv',sql=qry)

df_atcroute.describe(include='all')

pd.pivot_table(df_atcroute.groupby(['ddd','bnf']).size().reset_index(),values=0,index='ddd',columns='bnf',aggfunc='sum',margins=True)

# How many VMPs for each ATC-route class described above?

#df_atcroute.groupby(['ddd','bnf']).sum()
pd.pivot_table(df_atcroute.groupby(['ddd','bnf']).sum().reset_index(),values='vmps',index='ddd',columns='bnf',aggfunc='sum',margins=True)
