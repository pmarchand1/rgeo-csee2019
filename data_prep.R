### Script to produce the data files for "Introduction to geospatial data analysis in R"
### from the original public data sources.


library(tidyverse)
library(sf)
library(raster)

#### County regional municipalities ####

# Sources
# MRC polygons: https://mern.gouv.qc.ca/territoire/portrait/portrait-donnees-mille.jsp
# Population data: https://www.stat.gouv.qc.ca/statistiques/population-demographie/structure/mrc-total.xlsx


mrc <- read_sf("mrc")
mrc <- mrc %>%
    select(mrc_name = MRS_NM_MRC, reg_id = MRS_CO_REG, reg_name = MRS_NM_REG) %>%
    group_by(mrc_name) %>%
    summarize(reg_id = first(reg_id), reg_name = first(reg_name))
mrc$mrc_name[84] <- "Eeyou Istchee"

mrc_pop <- readxl::read_excel("mrc/mrc-total.xlsx", skip = 4) 
colnames(mrc_pop) <- c("id", "mrc_name", "region", 1996:2018)
mrc_pop$mrc_name[104] <- "Eeyou Istchee"

mrc <- inner_join(mrc, select(mrc_pop, mrc_name, pop2016 = "2016"))

mrc <- mutate_if(mrc, is_character, ~ stringi::stri_trans_general(., "Latin-ASCII"))

st_write(mrc, "data/mrc.shp")


#### Forest inventory plots ####

# Source: https://www.donneesquebec.ca/recherche/fr/dataset/placettes-echantillons-permanentes-1970-a-aujourd-hui

plots <- read_sf("PEP.gdb", "PLACETTE")

plots_meas <- read_sf("PEP.gdb", "PLACETTE_MES")
plots_meas <- filter(plots_meas, str_detect(VERSION, "^4e")) %>%
    group_by(ID_PE) %>%
    filter(NO_MES == max(NO_MES))

charac <- read_sf("PEP.gdb", "PEE_ORI_SOND")

plots <- inner_join(plots, plots_meas) %>%
    inner_join(charac) %>%
    select(plot_id = ID_PE, lat = LATITUDE, long = LONGITUDE,
           surv_date = DATE_SOND, cover_type = TYPE_COUV, height_cls = CL_HAUT) %>%
    st_drop_geometry()

plots$surv_date <- as.Date(plots$surv_date)

plots$height_cls <- recode(plots$height_cls, `1` = ">22 m", `2` = "17-22 m", 
                           `3` = "12-17 m",`4` = "7-12 m", `5` = "4-7 m", 
                           `6` = "2-4 m", `7` = "0-2 m")

plots$cover_type <- recode(plots$cover_type, F = "Deciduous", M = "Mixed",
                           R = "Coniferous")

plots <- na.omit(plots)

write_csv(plots, "data/plots.csv")


#### Spruce budworm ####

# Source: https://www.donneesquebec.ca/recherche/fr/dataset/donnees-sur-les-perturbations-naturelles-insecte-tordeuse-des-bourgeons-de-lepinette

tbe2014_2018 <- read_sf("TBE_2014_2018")
tbe2016 <- filter(tbe2014_2018, ANNEE == 2016)

reg_01_11 <- filter(mrc, reg_id %in% c("01", "11")) %>%
    st_union()
reg_01_11 <- st_as_sf(data.frame(geometry = reg_01_11))

tbe2016 <- st_join(tbe2016, reg_01_11, left = FALSE)
tbe2016 <- select(tbe2016, level = Ia, area_ha = SupHaCea) 

st_write(tbe2016, "data/tbe2016_gaspe.shp")


#### Canadian Digital Elevation Model ####

# Source: https://open.canada.ca/data/en/dataset/7f245e4d-76c2-4caa-951a-45d1d2051333

cdem22b <- raster("cdem/cdem_dem_022B.tif")
cdem22c <- raster("cdem/cdem_dem_022C.tif") 

cdem22bc <- merge(cdem22b, cdem22c)
aggregate(cdem22bc, fact = 4, filename = "data/cdem_022BC_3s.tif")


