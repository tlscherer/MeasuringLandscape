# These functions are used for the bias rmd


# https://github.com/dmlc/xgboost/blob/master/demo/kaggle-higgs/higgs-train.R

# install.packages("drat", repos="https://cran.rstudio.com")
# drat:::addRepo("dmlc")
# install.packages("xgboost", repos="http://dmlc.ml/drat/", type = "source")
# install.packages("xgboost")

#' This function takes in events data, and a vector of labels for whether that value would be imputed or missing, and then fits
#' A model predicting that missingness
#' Tries to predict in terms of properties of each event, e.g. DV
predict_missingness_dv <- function(label) {
  p_load(xgboost, dummies)

  vars_x <- c(
    "document_district_clean",
    "document_unit_type",
    "document_date_best_year",
    "document_date_type",
    "event_date_clean_year",
    "target_clean_1_aggmed",
    "initiator_clean_1_aggmed",
    "type_clean_aggmed",
    "rebels_government_civilians_killed_clean"
  )
  setdiff(vars_x, names(events_sf))
  x_all <- as.data.frame(events_sf)[, vars_x]
  x_all_pre_dummy <- x_all
  x_all <- dummy.data.frame(x_all)

  # label= label #
  sumwneg <- sum(label == 0)
  sumwpos <- sum(label == 1)

  dtrain <- xgb.DMatrix(data = as.matrix(x_all), label = label, missing = NA)

  param <- list(
    "objective" = "binary:logistic", # "objective" = logregobj,
    "scale_pos_weight" = sumwneg / sumwpos,
    "eta" = 0.3,
    "max_depth" = 6,
    "eval_metric" = "auc",
    "silent" = 1,
    "nthread" = 48,
    "maximize" = T
  )

  xb <- xgb.cv(
    params = param,
    data = dtrain,
    nrounds = 50,
    early_stopping_rounds = 10,
    nfold = 5,
    prediction = T
  )

  xb2 <- xgb.train(
    params = param,
    data = dtrain,
    nrounds = 100,
    # early_stopping_rounds=10,
    # nfold=5,
    prediction = T
  )
  # Store predictions so we can get area under the precision recall curve

  # predict(xb2, dtrain)

  # p_load(precrec)
  # msmdat1 <- evalmod( scores=xb$pred, labels=label)  # mode="basic"
  # msmdat1
  # autoplot(msmdat1)

  # area_under_prc <- attr(msmdat1,"aucs")$aucs[2]
  # area_under_prc

  p_load(Metrics)
  return(list(label = label, xb = xb$pred, xb_model = xb2, x_all_pre_dummy = x_all_pre_dummy, postdummy = x_all, dtrain = dtrain))

  # importance_importance <- xgb.importance(feature_names=vars_x, model = xb) #won't calculate on cv
  # xgb.plot.importance(importance_importance)
}




#' This function takes in events data, and a vector of labels for whether that value would be imputed or missing, and then fits
#' A model predicting that missingness
#' Tries to predict as a function of RHS covariates
predict_missingness_rhs <- function(condition) {
  vars_y <- "imputed"
  vars_x <- c("district", "cadastral", "language", "tribe", "rain", "population", "treecover", "ruggedness", "roads_distance", "landuse")
  vars_all <- c(vars_x, vars_y)
  xy_all <- rbindlist(
    list(
      as.data.frame(georef_all_dt_covariates_events_sf)[, vars_all], # Ok so this is all events
      as.data.frame(
        subset(
          subset(georef_all_dt_covariates_gaz_sf, condition),
          !duplicated(event_hash)
        ) # arbitarily pick one per event
      )[, vars_all] # And these are just the ones that meet the criteria
    )
  )
  xy_all <- as.data.frame(xy_all)

  p_load(xgboost, dummies)

  label <- xy_all$imputed

  x_all <- xy_all[, vars_x]
  x_all <- dummy.data.frame(x_all)

  # label= label #
  sumwneg <- sum(label == 0)
  sumwpos <- sum(label == 1)

  dtrain <- xgb.DMatrix(data = as.matrix(x_all), label = label, missing = NA)

  param <- list(
    "objective" = "binary:logistic", # "objective" = logregobj,
    "scale_pos_weight" = sumwneg / sumwpos,
    "eta" = 0.3,
    "max_depth" = 6,
    "eval_metric" = "auc",
    "silent" = 1,
    "nthread" = 48,
    "maximize" = T
  )

  xb <- xgb.cv(
    params = param,
    data = dtrain,
    nrounds = 200,
    early_stopping_rounds = 10,
    nfold = 5,
    prediction = T
  )

  # xb2 <- xgb.train(params=param,
  #             data=dtrain,
  #             nrounds = 50,
  #             #early_stopping_rounds=10,
  #             nfold=5,
  #             prediction=T)
  #
  # importance_importance <- xgb.importance(feature_names=colnames(dtrain), model = xb2) #won't calculate on cv
  # xgb.plot.importance(importance_importance)
  #
  return(list(label = label, xb = xb$pred, xb = xb, dtrain = dtrain))
}