install.packages('dplyr')
library(foreign)
library(dplyr)

#A.1.2.1 Set file path for main folder and DTA files folder¶
path = getwd()

#A.2.1.1 Import weekly variables data "i_cs"¶
df1 = read.dta(paste(path,'/hh02dta_b1/i_cs.dta', sep=''))
df1 = as_tibble(df1)
df1 = df1 %>% rename(Household_id = folio)

#A.2.1.2 Select weekly consumption variables
cons1 = df1 %>%
  select(Household_id,
         intersect(contains('cs02a_'), ends_with('2')))

#A.2.1.2.1 Convert weekly varibles to monthly vars
cons1 = cons1 %>% 
  mutate_at(vars(cs02a_12:cs02a_82),.funs = funs(. *4.3))


#A.2.2 Monthly variables
cons2 = df1 %>%
  select(Household_id,
         intersect(contains('cs16'), ends_with('2')))

#A.2.3 3-Month variables¶
#A.2.3.1 Import weekly variables data "i_cs1"¶
df2 = read.dta(paste(path,'/hh02dta_b1/i_cs1.dta', sep=''))
df2 = as_tibble(df2)
df2 = df2 %>% rename(Household_id = folio) #Rename

#A.2.1.3.1 Convert 3-month varibles to monthly vars¶
cons3 = df2 %>%
  select(Household_id,
         intersect(contains('cs22'), ends_with('2')))

cons3 = cons3 %>% 
  mutate_at(vars(cs22a_2:cs22h_2),.funs = funs(. /3))

#A.2.4 Merge consumption variables into one dataframe¶
merge1 = merge(cons1, cons2, by = 'Household_id', all= TRUE)
cons_merge = merge(merge1, cons3, by = 'Household_id', all= TRUE)
#head(cons_merge,3)

#1.1.1 Calculate total consumer spending¶
total_cons = cons_merge %>% 
  mutate(consumption = select(cons_merge,-Household_id)%>% {rowSums(.)})
total_cons[["consumption"]][is.na(total_cons[["consumption"]])] <- 0


#Q.1.2 Per capita consumption (Total/house size)¶
df_housesize = read.dta(paste(path,'/hh02dta_bc/c_ls.dta', sep=''))
df_housesize = as_tibble(df_housesize) #Set as tibble

#1.2.1.2 Count family members "ls" in each household "folio"¶
family_members = df_housesize %>% group_by(folio) %>% count(folio)  
family_members = family_members%>% rename(family_members = n, Household_id=folio)

#1.2.1.2 Family members graph
hist(family_members$family_members)

#1.3 Per capita consumption (Total/house size)
#1.3.1 Merge family_members and consumption data set¶
#1.3.1.2 Merge two data sets and drop na values¶
percap_consum = merge(family_members, total_cons, by='Household_id')

#1.3.1.3 Calculate percapita consumption¶
percap_consum = percap_consum %>%
  mutate(percap_consum = percap_consum$consumption/percap_consum$family_members)
percap_consum%>% head(3)

#1.3.1.4 Percap consumption summary¶
summary(percap_consum)

#write.csv(percap_consum, 'R_data.csv')

#2.1 Headcount using 500 as an example¶
povertyline = 500
below_poverty = percap_consum %>%
  filter(percap_consum < povertyline )%>% select(percap_consum) 

observations = length(percap_consum$percap_consum)
head_count = length(below_poverty$percap_consum)/observations
print(paste('Headcount: ', round(head_count*100, 2),'%', sep=''), quote=FALSE)

#2.2 Avg. poverty gap¶
mean(povertyline-below_poverty$percap_consum)

#2.3 Avg. poverty gap squared¶
mean((povertyline-below_poverty$percap_consum)**2)

#3.1. Import residence data from "c_portad"¶
residence_df = read.dta(paste(path,'/hh02dta_bc/c_portad.dta', sep=''))
residence_df = residence_df%>% rename(Household_id = folio)
head(residence_df)

#3.1.1. Merge residence df with percap_consum df from Q.1 & Q.2¶
consum_residence_df  = merge(residence_df, percap_consum, by='Household_id')
consum_residence_df  = as_tibble(consum_residence_df)
consum_residence_df %>% head(3)

#3.1.1.2 Create poverty dummy¶
consum_residence_df$poverty_dummy <- as.numeric(consum_residence_df$percap_consum<povertyline)
consum_residence_df %>% filter(poverty_dummy ==1) #Show observations 

#3.2 Show poverty by area of residence¶
consum_residence_df %>% 
  group_by(estrato) %>% #Groupby estrato
  count(poverty_dummy) %>% #Count poverty dummy by each estrato
  mutate(obs = sum(n))%>% 
  mutate(head_count = (n/obs)*100)%>% 
  filter(poverty_dummy==1) %>% 
  select(estrato, head_count)

#4.1 Calculate cumulative sum for population and consumption¶
gini = percap_consum %>% 
  arrange(percap_consum) %>% #Sort consumption from least to greatest
  mutate(consum_cumulative = cumsum(percap_consum), consum_total = sum(percap_consum), pop_total = sum(family_members), pop_cumulative = cumsum(family_members))%>% #Calculate total and cumulative sum for variables 
  mutate(consum_pct = (consum_cumulative/consum_total), pop_pct = ((pop_cumulative/ pop_total))) #Calculate quintiles
gini %>% head(3) #Show new data

gini[is.na(gini)] <- 0

#4.1.1 Plot:¶
install.packages("ggplot2")
library(ggplot2)
ggplot(data= gini, aes(x=pop_pct, y= consum_pct))+ 
  ggtitle("Lorenz curve")+theme(plot.title = element_text(hjust = 0.5))+ 
  geom_line()+ 
  geom_abline(intercept = 0, slope = 1, color='red')+xlab('cum. % of households')+ylab('cum. % consum/percap')


cov_consum_V_consum_pct = cov(gini$percap_consum, gini$consum_pct) 
mean_cons = mean(gini$percap_consum)
print((2*cov_consum_V_consum_pct)/(mean_cons))

# 4.2 4.2 Urban vs. Rural: Lorenz and Gini¶
#4.2.1.1 Urban: Calculate cumulative sum for population and consumption¶
urban = consum_residence_df %>% 
  arrange(percap_consum) %>%
  select(estrato,percap_consum, family_members)%>%
  filter(estrato==1 | estrato==2)%>% #select estrato 1&2 MOST IMPORTANT CODE
  mutate(consum_cumulative = cumsum(percap_consum), consum_total = sum(percap_consum), pop_total = sum(family_members), pop_cumulative = cumsum(family_members))%>% #Calculate total and cumulative sum for variables 
  mutate(consum_pct = (consum_cumulative/consum_total), pop_pct= ((pop_cumulative/ pop_total))) #Calculate quintiles

#4.2.1.2 Plot Lorenz curve for Urban¶
ggplot(data= urban, aes(x=pop_pct, y= consum_pct))+ 
  ggtitle("Lorenz curve")+theme(plot.title = element_text(hjust = 0.5))+ 
  geom_line()+ 
  geom_abline(intercept = 0, slope = 1, color='red')+xlab('cum. % of households')+ylab('cum. % consum/percap')

#4.2.1.3 Urban: Gini coefficient¶
cov_consum_V_consum_pct = cov(urban$percap_consum, urban$consum_pct) 
mean_cons = mean(urban$percap_consum)
print((2*cov_consum_V_consum_pct)/(mean_cons))

#4.2.2.1 Rural: Calculate cumulative sum for population and consumption¶
rural = consum_residence_df %>% 
  arrange(percap_consum) %>%
  select(estrato,percap_consum, family_members)%>%
  filter(estrato==3 | estrato==4)%>% #select estrato 1&2 MOST IMPORTANT CODE
  mutate(consum_cumulative = cumsum(percap_consum), consum_total = sum(percap_consum), pop_total = sum(family_members), pop_cumulative = cumsum(family_members))%>% #Calculate total and cumulative sum for variables 
  mutate(consum_pct = (consum_cumulative/consum_total), pop_pct= ((pop_cumulative/ pop_total))) #Calculate quintiles

rural %>%tail(3)

#4.2.1.2 Plot Lorenz curve for Urban¶

ggplot(data= rural, aes(x=pop_pct, y= consum_pct))+ 
  ggtitle("Lorenz curve")+theme(plot.title = element_text(hjust = 0.5))+ 
  geom_line()+ 
  geom_abline(intercept = 0, slope = 1, color='red')+xlab('cum. % of households')+ylab('cum. % consum/percap')
#4.2.1.3 Urban: Gini coefficient¶
cov_consum_V_consum_pct = cov(rural$percap_consum, rural$consum_pct) 
mean_cons = mean(rural$percap_consum)
print((2*cov_consum_V_consum_pct)/(mean_cons))