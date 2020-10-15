## Script looking at the prescribing of asthma mAbs in secondary care
## Can't connect to big query directly as using nhs computer but sql script used to extract data in comments below

## Anna Rowan
## 29/09/20

install.packages("dplyr")
install.packages("tidyverse")
install.packages("reshape")
install.packages("scales")
install.packages("ggplot2")
install.packages("bigrquery")
install.packages("here")

library(dplyr)
library(tidyverse)
library(reshape)
library(scales)
library(ggplot2)
library(bigrquery)
library(DBI)

setwd("C:/Users/HP/Documents/EBM_DL")
options(scipen = 999)

## read in SCMD data from DataLab BigQuery
con <- dbConnect(
  bigrquery::bigquery(),
  project = "ebmdatalab",
  dataset = "scmd")

dbListTables(con)

scmd_extract_asthma_mabs <- "select 
year_month,
ods_code,
vmp_snomed_code,
vmp_product_name,
sum(total_quanity_in_vmp_unit) as total_quantity
from ebmdatalab.scmd.scmd
where 
vmp_snomed_code = \"18671311000001102\" or 
vmp_snomed_code = \"18671411000001109\" or
vmp_snomed_code = \"37564311000001105\" or
vmp_snomed_code = \"37564411000001103\" or
vmp_snomed_code = \"31210311000001108\" or
vmp_snomed_code = \"33999611000001101\" or
vmp_snomed_code = \"34812511000001102\" or
vmp_snomed_code = \"37854611000001108\" or
vmp_snomed_code = \"35298511000001102\"
group by
year_month,
ods_code,
vmp_snomed_code,
vmp_product_name
order by
year_month"

scmd_asthma_mabs <- dbGetQuery(con, scmd_extract_asthma_mabs)

dmd_extract_asthma_mabs <- "select 
  cast(a.id as STRING) as vmpid,
  a.nm as vmpnm,
  a.vtm as vtmid,
  j.nm as vtmnm,
  b.form as form_cd,
  c.descr as formdescr,
  a.df_ind as df_ind_cd,
  d.descr as df_descr,
  a.udfs,
  e.descr as udfs_descr,
  f.descr as unit_dose_descr,
  g.strnt_nmrtr_val,
  h.descr as strnt_nmrtr_uom,
  g.strnt_dnmtr_val,
  i.descr as strnt_dnmtr_descr,
  a.bnf_code,
  k.presentation as bnf_presentation
  
from ebmdatalab.dmd.vmp as a

left join ebmdatalab.dmd.dform as b
on a.id = b.vmp

left join ebmdatalab.dmd.form as c
on b.form = c.cd

left join ebmdatalab.dmd.dfindicator as d
on a.df_ind = d.cd

left join ebmdatalab.dmd.unitofmeasure as e
on a.udfs_uom = e.cd

left join ebmdatalab.dmd.unitofmeasure as f
on a.unit_dose_uom = f.cd

left join ebmdatalab.dmd.vpi as g
on a.id = g.vmp

left join ebmdatalab.dmd.unitofmeasure as h
on g.strnt_nmrtr_uom = h.cd

left join ebmdatalab.dmd.unitofmeasure as i
on g.strnt_dnmtr_uom = i.cd

left join ebmdatalab.dmd.vtm as j
on a.vtm = j.id

left join ebmdatalab.hscic.bnf as k
on a.bnf_code = k.presentation_code

where
  a.id = 18671311000001102 or 
  a.id = 18671411000001109 or
  a.id = 37564311000001105 or
  a.id = 37564411000001103 or
  a.id = 31210311000001108 or
  a.id = 33999611000001101 or
  a.id = 34812511000001102 or
  a.id = 37854611000001108 or
  a.id = 35298511000001102"

dmd_asthma_mabs <- dbGetQuery(con, dmd_extract_asthma_mabs) %>% 
  dplyr::rename(vmp_product_name = vmpnm) %>%
  select(-c("vmpid"))

# reading in ods data on hospitals - no header information so need to add this in
hospital_to_stp_map <- read.csv(file = "./Reference_Data/etr.csv", header = FALSE) %>%
  select(1:4) 
colnames(hospital_to_stp_map) <- c("ods_code", "trust_name", "region_code", "stp_code")

# reading in map from ccg codes to stp and region codes because this gives a map from stp_code to stp_name
# published on nhs digital site: https://digital.nhs.uk/data-and-information/publications/statistical/patients-registered-at-a-gp-practice/september-2020
stp_to_region_map <- read.csv("./Reference_Data/gp-reg-pat-prac-map.csv") %>%
  group_by(STP_CODE, STP_NAME) %>%
  summarise(COMM_REGION_NAME = first(COMM_REGION_NAME),
            COMM_REGION_CODE = first(COMM_REGION_CODE)) %>%
  dplyr::rename(stp_code = STP_CODE)

## From WHO ATC/DDD index page
# Omalizumab DDD = 16mg https://www.whocc.no/atc_ddd_index/?code=R03DX05
# Mepolizumab DDD = 3.6mg https://www.whocc.no/atc_ddd_index/?code=R03DX09
# Reslizumab DDD = 7.1mg https://www.whocc.no/atc_ddd_index/?code=R03DX08
# Benralizumab DDD = 0.54mg https://www.whocc.no/atc_ddd_index/?code=R03DX10


# Merging datasources together
asthma_mabs <- left_join(scmd_asthma_mabs, dmd_asthma_mabs, by = "vmp_product_name") %>%
  left_join(., hospital_to_stp_map, by = "ods_code") %>%
  # some data cleaning as scmd uses some ods codes that are not up to date
  mutate(stp_code = as.character(stp_code),
         stp_code = ifelse(ods_code == "RQ6", "QYG",
                           ifelse(ods_code %in% c("RNL","RE9","RLN"), "QHM",
                                  ifelse(ods_code %in% c("RM2", "RW3"), "QOP",
                                         ifelse(ods_code == "RGQ", "QJG",
                                                ifelse(ods_code == "RJF", "QJ2",
                                                       ifelse(ods_code == "RR1", "QHL", stp_code))))))) %>%
  left_join(., stp_to_region_map, by = "stp_code") %>%
  select(-c("COMM_REGION_CODE"))

# SCMD volumes data is provided in vmp quantity - this means different things for different products 
# e.g. 100mg powder = 1 vmp quantity but 100mg/20ml solution for injection = 20 vmp quantity, even though moth VMPS have same strength of ingredient
# need to translate vmp quantity volume to units of singles of product, and then total strength and then DDDs

asthma_mabs_with_DDD <- asthma_mabs %>%
  mutate(volume_singles = total_quantity / udfs,
         volume_mg_strength = volume_singles * ifelse(is.na(strnt_dnmtr_val),strnt_nmrtr_val, strnt_nmrtr_val * (udfs / strnt_dnmtr_val)),
         mg_per_DDD = ifelse(vtmnm == "Omalizumab", 16,
                             ifelse(vtmnm == "Mepolizumab", 3.6,
                                    ifelse(vtmnm == "Reslizumab", 7.1,
                                           ifelse(vtmnm == "Benralizumab", 0.54, NA)))),
         volume_DDD = volume_mg_strength / mg_per_DDD)


# Now should have all product volume described using same unit, 
# so should be able to directly compare across VMPs and VTMs

## Use over time - National and Regional

Nat_time_series <- asthma_mabs_with_DDD %>%
  group_by(year_month, vtmnm) %>%
  summarise(volume_DDD = sum(volume_DDD))

ggplot(Nat_time_series, aes(x = year_month, y = volume_DDD, group = vtmnm)) +
  geom_line(aes(color = vtmnm), size = 2) +
  labs(x = "Month", y = "Total volume issued in hospitals - DDD") +
  scale_y_continuous(labels = scales::number) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90)) +
  ggtitle("Prescribing of asthma mAbs over time - National")

Reg_time_series <- asthma_mabs_with_DDD %>%
  group_by(COMM_REGION_NAME, year_month, vtmnm) %>%
  summarise(volume_DDD = sum(volume_DDD))

ggplot(Reg_time_series, aes(x = year_month, y = volume_DDD, group = COMM_REGION_NAME)) +
  geom_line(aes(color = COMM_REGION_NAME), size = 2) +
  facet_wrap(~vtmnm) +
  labs(x = "Month", y = "Total volume issued in hospitals - DDD") +
  scale_y_continuous(labels = scales::number) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90),
        legend.position = "bottom") +
  ggtitle("Prescribing of asthma mAbs over time - Regional")

## Comparing use by type of chemical at a regional and trust level

# Look at regional use by product
Reg_split <- asthma_mabs_with_DDD %>%
  filter(year_month >= as.Date("2019-08-01") & year_month <= as.Date("2020-07-01")) %>%
  group_by(COMM_REGION_NAME, vtmnm) %>%
  summarise(volume_DDD = sum(volume_DDD)) %>%
  group_by(COMM_REGION_NAME) %>%
  mutate(prop_use = volume_DDD / sum(volume_DDD),
         pos = cumsum(volume_DDD) - volume_DDD/2,
         total = sum(volume_DDD)) %>%
  ungroup() %>%
  arrange(desc(total))

ggplot(data = Reg_split, aes(x = reorder(COMM_REGION_NAME,total), y = volume_DDD, fill = vtmnm)) +
  geom_bar(position = "stack", stat = "identity") +
  theme_bw() +
  labs(x = "Region",
       y = "Volume of asthma mAbs issues - DDDs") +
  theme(strip.text.x = element_text(size = 8),
        legend.position = "bottom") + 
  scale_y_continuous(labels = scales::number) +
  ggtitle(label = "Regional use of asthma mAbs",
          subtitle = "Between August 2019 and July 2020")

# Look at trust use by product
Trust_split <- asthma_mabs_with_DDD %>%
  filter(year_month >= as.Date("2019-08-01") & year_month <= as.Date("2020-07-01")) %>%
  group_by(trust_name, ods_code, vtmnm) %>%
  summarise(volume_DDD = sum(volume_DDD)) %>%
  group_by(trust_name, ods_code) %>%
  mutate(prop_use = volume_DDD / sum(volume_DDD),
         pos = cumsum(volume_DDD) - volume_DDD/2,
         total = sum(volume_DDD)) %>%
  ungroup() %>%
  arrange(desc(total))

# stacked bar chart
ggplot(data = Trust_split, aes(x = reorder(ods_code,total), y = volume_DDD, fill = vtmnm)) +
  geom_bar(position = "stack", stat = "identity") +
  theme_bw() +
  labs(x = "Trust",
       y = "Volume of asthma mAbs issues - DDDs") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1),
        strip.text.x = element_text(size = 8),
        legend.position = "bottom") + 
  scale_y_continuous(labels = scales::number) +
  ggtitle(label = "Trust use of asthma mAbs",
          subtitle = "Between August 2019 and July 2020")

# scatter plot - total asthma mAb prescribing by % Omalizumab
trust_volume_by_prop_Omal <- asthma_mabs_with_DDD %>%
  filter(year_month >= as.Date("2019-08-01") & year_month <= as.Date("2020-07-01")) %>%
  mutate(vol_omalizumab = ifelse(vtmnm == "Omalizumab", volume_DDD, 0)) %>%
  group_by(ods_code) %>%
  summarise(volume_DDD = sum(volume_DDD),
            prop_omalizumab = sum(vol_omalizumab) / sum(volume_DDD)) %>%
  arrange(desc(volume_DDD))

ggplot(trust_volume_by_prop_Omal, aes(x = volume_DDD, y = prop_omalizumab)) +
  geom_point(size = 2) +
  labs(x = "Total asthma mAb issues in DDDs", y = "% of total volume through Omalizumab") +
  scale_x_continuous(labels = scales::number) +
  scale_y_continuous(labels = scales::percent) +
  theme_bw() +
  ggtitle(label = "Comparing trust level prescribing of Asthma mAbs and proportion of prescribing through Omalizumab",
          subtitle = "Between August 2019 and July 2020")


# Top 20 trusts
Trust_split_Top20 <- Trust_split %>%
  mutate(rank = dense_rank(desc(total))) %>%
  arrange(desc(total)) %>%
  filter(rank <= 20) %>%
  mutate(trust_name = as.character(trust_name),
         trust_name = ifelse(ods_code == "RM2", "UNIVERSITY HOSPITAL OF SOUTH MANCHESTER NHS FOUNDATION TRUST",
                             ifelse(ods_code == "RR1", "HEART OF ENGLAND NHS FOUNDATION TRUST",
                                    trust_name)))

ggplot(data = Trust_split_Top20, aes(x = reorder(trust_name,total), y = volume_DDD, fill = vtmnm)) +
  geom_bar(position = "stack", stat = "identity") +
  theme_bw() +
  labs(x = "Trust",
       y = "Volume of asthma mAbs issues - DDDs") +
  theme(legend.position = "bottom") + 
  scale_y_continuous(labels = scales::number) +
  ggtitle(label = "Trust use of asthma mAbs - Top 20 trusts by DDD volume",
          subtitle = "Between August 2019 and July 2020") +
  coord_flip()
