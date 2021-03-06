# Import and prepare data in GRASS GIS and model species distribution in R

# install packages
# run for the first time only if you don't have the packages already
# source("install.R")

# load rgrass7 package
library(sp)
library(rgrass7)
# tell rgrass7 to use sp not stars
use_sp()

# load additional helper GRASS-related functions
source("createGRASSlocation.R")

# ----- Specify path to GRASS GIS installation -----
grassExecutable <- "grass"
# You need to change the above to where GRASS GIS is on your computer.
# On Windows, it will look something like:
# grassExecutable <- "C:/Program Files/GRASS GIS 7.8/grass78.bat"

# ----- Specify path to data -----
dem <-  "dem.tif"
database <- "grassdata"
location <- "sdm"
mapset <- "PERMANENT"
# you need to change the above to where the data is and should be on your computer
# on Windows, it will look something like:
# dem <-  "C:/Users/gabor/OneDrive/Desktop/R_grassgis/dem.tif"
# database <- "C:/Users/gabor/grassdata"


# ----- Create GRASS location -----

# pick one option (here, we are using the file we have):

# A) create a new GRASS location based on georeferenced file
createGRASSlocation(grassExecutable = grassExecutable,
                    readProjectionFrom = dem,
                    database = database,
                    location = location)

# B) create a new GRASS location with EPSG code 4326
# createGRASSlocation(grassExecutable = grassExecutable,
#                     EPSG = 4326,
#                     database = database,
#                     location = location)


# ----- Initialisation of GRASS -----
initGRASS(gisBase = getGRASSpath(grassExecutable),
          gisDbase = database,
          location = location,
          mapset = mapset,
          override = TRUE)


# ----- Import and create rasters for modeling -----
execGRASS("r.in.gdal", input=dem, output="dem") # Import digital elevation model (DEM) to GRASS GIS

dem <- readRAST("dem", cat=FALSE) # load DEM to R

plot(dem, main = "Digital Elevation Model", col=terrain.colors(50)) # plot DEM

execGRASS("r.topidx", input = "dem", output = "twi") # calculate topographic wetness index (TWI)

execGRASS("r.slope.aspect", elevation="dem", slope="slope", aspect="aspect") # calculate slope, aspect

execGRASS("r.info", map="aspect") # show raster info

execGRASS("r.out.gdal", input="twi", output="twi.tif", format="GTiff") # export data to GeoTIFF
execGRASS("r.out.gdal", input="slope", output="slope.tif", format="GTiff")
execGRASS("r.out.gdal", input="aspect", output="aspect.tif", format="GTiff")

# ----- Load environmental data to R -----
library(raster)
# A) Directly from GRASS GIS (wrong option)
twi2 <- raster(readRAST("twi", cat=FALSE))

# B) Load previously saved GeoTIFF files
twi <- raster("twi.tif")
slope <- raster("slope.tif")
dem <- raster("dem.tif")
aspect <- raster("aspect.tif")

# Compare twi and twi2 - Is data source same for both layers? If not, how it may impact next modeling? 

# ----- Species distribution modeling (SDM) -----
library(usdm)
library(dismo)

preds <- stack(slope, twi, aspect, dem) # stack environmental layers
plot(preds)

# VIF - Variance Inflation Factor; check the collinearity problem in environmental variables
v <- vifstep(preds);v
preds <- exclude (preds, v)

sp <- shapefile("virtualis") # Load species data

bg <- randomPoints(preds, 1000, p = sp) # create background points

# Divide species data for testing and training the model
fold <- kfold(sp, k=5) # divide species occurrences to 5 folds (20% for testing the model)

test <- sp[fold == 1, ]
train <- sp[fold != 1, ]

# fit the bioclim model using environmental data (preds) and training species data (train)
bioclim.model <- bioclim(preds, train)

# predict probability species distribution
prediction <- predict(preds, bioclim.model)

par(mfrow = c(1, 1))
plot(prediction, main='Predicted Probability - Virtualis') # plot prediction
