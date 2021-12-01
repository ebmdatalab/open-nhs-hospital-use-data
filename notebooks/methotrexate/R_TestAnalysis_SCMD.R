## Code book used to explore the secondary care medicines dataset (SCMD)
## Looking at issues of Methotrexate tablets

## First steps are to install packages, call libraries and set working directorate

# install.packages("bigrquery")
# install.packages("dplyr")
# install.packages("tidyverse")
# install.packages("reshape")
# install.packages("DT")

library(bigrquery)
library(dplyr)
library(tidyverse)
library(reshape)
library(DBI)
library(scales)
library(readxl)
library(DT)

setwd("C:/Users/User/Documents/GitHub/open-nhs-hospital-use-data/")


## Then need to get data from bigquery

con <- dbConnect(
  bigrquery::bigquery(),
  project = "ebmdatalab",
  dataset = "scmd"
)

dbListTables(con)

# Reading in data from the secondary care medicines dataset

sql_1 <- "select 
  year_month,
  ods_code,
  vmp_snomed_code,
  vmp_product_name,
  sum(total_quanity_in_vmp_unit) as total_quantity

from ebmdatalab.scmd.scmd

where vmp_snomed_code = \"326875008\" or vmp_snomed_code = \"326874007\"

group by
  year_month,
  ods_code,
  vmp_snomed_code,
  vmp_product_name
  
order by
  year_month"

hospital_data <- dbGetQuery(con, sql_1)

# Reading in data from the primary care prescribing dataset 

sql_2 <- "select
  month, 
  pct,
  bnf_code,
  bnf_name,
  sum(total_quantity) as quantity
 
from ebmdatalab.hscic.raw_prescribing_normalised

where
  (bnf_code = \"1001030U0AAACAC\" or
  bnf_code = \"1001030U0AAABAB\") and
  month >= cast(\"2019-01-01\" as datetime)
  
group by
  month,
  pct,
  bnf_code,
  bnf_name

order by
  month"

community_data <- dbGetQuery(con, sql_2)

# disconnecting from bigquery
dbDisconnect(con)


# reading in ods data on hospitals - no header information so need to add this in
hospital_to_stp_map <- read.csv(file = "./data/etr.csv", header = FALSE) %>%
  select(1:4) 
colnames(hospital_to_stp_map) <- c("ods_code", "trust_name", "region_code", "stp_code")

ccg_to_stp_map <- read.csv("./data/gp-reg-pat-prac-map.csv") %>%
  group_by(CCG_CODE) %>%
  summarise(STP_CODE = first(STP_CODE),
            STP_NAME = first(STP_NAME),
            COMM_REGION_NAME = first(COMM_REGION_NAME),
            COMM_REGION_CODE = first(COMM_REGION_CODE))


# saving hospital data and community data as csvs, so don't need to extract from big query again
write.csv(hospital_data, file = "./data/methotrexate_hospital_data.csv")
write.csv(community_data, file = "./data/methotrexate_community_data.csv")


# merge stp information on to hospital dataset
hospital_data_with_stp <- left_join(hospital_data, hospital_to_stp_map, by = "ods_code") %>%
  mutate(source = "hospital") %>%
  dplyr::rename(month = year_month,
                stp = stp_code,
                product_name = vmp_product_name,
                quantity = total_quantity) %>%
  group_by(month, stp, source, product_name) %>%
  summarise(quantity = sum(quantity)) %>%
  mutate(COMM_REGION_NAME = NA,
         STP_NAME = NA)

combined_data <- community_data %>%
  mutate(source = "community") %>%
  dplyr::rename(product_name = bnf_name,
                CCG_CODE = pct) %>%
  select(month, CCG_CODE, source, product_name, quantity) %>%
  left_join(., ccg_to_stp_map, by = "CCG_CODE") %>%
  group_by(COMM_REGION_NAME, STP_NAME, STP_CODE, month, source, product_name) %>%
  summarise(quantity = sum(quantity)) %>%
  dplyr::rename(stp = STP_CODE) %>%
  union(., hospital_data_with_stp) %>%
  filter(!is.na(stp)) %>%
  group_by(stp) %>%
  mutate(COMM_REGION_NAME = first(na.omit(COMM_REGION_NAME)),
         STP_NAME = first(na.omit(STP_NAME))) %>%
  ungroup() %>%
  filter(!is.na(STP_NAME))

unique(combined_data$stp)
unique(combined_data$COMM_REGION_NAME)
unique(combined_data$STP_NAME)
## Now can analyse the data in R

# National time series
national_time_series <- combined_data %>%
  group_by(month, source, product_name) %>%
  summarise(nat_quantity = sum(quantity)) %>%
  group_by(month, source) %>%
  mutate(prop_prescribing = nat_quantity / sum(nat_quantity)) %>%
  ungroup()

national_time_series_total <- national_time_series %>%
  group_by(month, source) %>%
  summarise(nat_total_quantity = sum(nat_quantity))

ggplot(national_time_series_total, aes(x = month, y = nat_total_quantity, group = source)) +
  geom_line(aes(color = source), size = 2) +
  labs(x = "Month", y = "Total methotrexate tablets") +
  scale_y_continuous(labels = scales::number) +
  theme_bw() +
  ggtitle("Prescribing of methotrexate tablets over time")
# Much higher volumes of methotrexate tablet prescribing in the community (is this expected?)


national_time_series_10mg <- national_time_series %>%
  filter(product_name == "Methotrexate 10mg tablets")

ggplot(national_time_series_10mg, aes(x = month, y = prop_prescribing, group = source)) +
  geom_line(aes(color = source), size = 2) +
  labs(x = "Month", y = "10mg tablets as a proportion of all methotrexate tablets") +
  scale_y_continuous(labels = scales::percent) +
  theme_bw() +
  ggtitle("Prescribing of 10mg tablets as a proportion of all methotrexate tablets over time")
# Prescribing of 10mg in the community shows a steady declining trend over time
# Prescribing of 10mg as % of all methotrexate tablets is similar between community and hospitals - but hospital more volitile and no clear trend






# Trust level variation
Trust_Time_Series <- Data %>%
  group_by(year_month, ods_code) %>%
  mutate(total_across_both_formulations = sum(total_quantity),
         prop_prescribing = total_quantity / sum(total_quantity)) %>%
  ungroup() %>%
  arrange(desc(total_across_both_formulations))

Trust_Chart <- Trust_Time_Series %>%
  filter(vmp_product_name == "Methotrexate 10mg tablets")

Deciles <- Trust_Time_Series %>%
  filter(vmp_product_name == "Methotrexate 10mg tablets") %>%
  group_by(year_month) %>%
  summarise(Percentile_10 = quantile(prop_prescribing, 0.1),
            Percentile_20 = quantile(prop_prescribing, 0.2),
            Percentile_30 = quantile(prop_prescribing, 0.3),
            Percentile_40 = quantile(prop_prescribing, 0.4),
            Percentile_50 = quantile(prop_prescribing, 0.5),
            Percentile_60 = quantile(prop_prescribing, 0.6),
            Percentile_70 = quantile(prop_prescribing, 0.7),
            Percentile_80 = quantile(prop_prescribing, 0.8),
            Percentile_90 = quantile(prop_prescribing, 0.9)) %>%
  as.data.frame() %>%
  melt(., id = c("year_month")) %>%
  dplyr::rename(ods_code = variable,
                prop_prescribing = value)

ggplot(data = Trust_Chart, aes(x = year_month, y = prop_prescribing, group = ods_code)) +
  geom_line() +
  geom_line(data = Deciles, colour = "red", linetype = "dashed") +
  labs(x = "Month", y = "Proportion of issues due to 10mg tablets") +
  scale_y_continuous(labels = scales::percent) +
  theme_bw() +
  ggtitle("Proportion of Methotrexate tablet issues through the 10mg tablets - variation in hospital issues over time")
# Hard to see what's going on in this chart
# Some trusts are very clear outliers in 10mg issues as proportion of the total
# But these trusts might have very low volumes - how to check this?
# Could just plot total volumes, but that will be skewed by hospital size and possibly speciality
  


## stp analysis

stp_july2019_june2020 <- combined_data %>%
  mutate(month = as.Date(month, "%Y-%m-%d"))%>%
  filter(month >= as.Date("2019-07-01") & month <= as.Date("2020-06-01"))%>%
  group_by(STP_NAME, stp, source, product_name) %>%
  summarise(stp_quantity = sum(quantity)) %>%
  group_by(stp) %>%
  mutate(prop_prescribing = stp_quantity / sum(stp_quantity)) %>%
  ungroup() %>%
  filter(product_name == "Methotrexate 10mg tablets") %>%
  group_by(stp) %>%
  mutate(total = sum(prop_prescribing)) %>%
  ungroup()

stp_table <- stp_july2019_june2020 %>%
  select(STP_NAME, stp, product_name, source, prop_prescribing) %>%
  cast(., STP_NAME + stp + product_name ~ source, vale = "prop_prescribing") %>%
  mutate(Total = community + hospital) %>%
  arrange(desc(Total))

ggplot(stp_july2019_june2020, aes(x = reorder(STP_NAME, total), y = prop_prescribing, fill = source)) +
  geom_bar(position = "stack", stat = "identity") +
  labs(x = "STP", y = "10mg tablets as a proportion of all methotrexate tablets") +
  scale_y_continuous(labels = scales::percent) +
  theme_bw() +
  theme(legend.position = "top") +
  ggtitle("Prescribing of methotrexate tablets (July 2019 to June 2020)") +
  coord_flip()

unique(combined_data$stp)
