cat("Plot capacities \n")

# Data preparation (REMIND) -----------------------------------------------


if (length(dieter.files) != 0) {
  
  out.remind.peak.demand <- NULL
  for (i in 2:(length(remind.files))){
    
    it <- as.numeric(str_extract(remind.files[i], "[0-9]+"))
    
    remind.peak.demand <- file.path(outputdir, remind.files[i]) %>%  
      read.gdx("p32_peakDemand", factor = FALSE) %>% 
      filter(ttot %in% model.periods.from2020) %>% 
      filter(all_regi == reg) %>%
      select(period=ttot,value) %>% 
      mutate(value = value * 1e3) %>% 
      mutate(iteration = it, model = "REMIND") %>% 
      mutate(var = "peak hourly residual demand")
    
    out.remind.peak.demand <- rbind(out.remind.peak.demand, remind.peak.demand)
  }
}

out.remind.capacity <- NULL

  for (i in 1:(length(remind.files))){
 
    it <- as.numeric(str_extract(remind.files[i], "[0-9]+"))
    
    remind.capacity <- file.path(outputdir, remind.files[i]) %>%  
      read.gdx("vm_cap", factors = FALSE, squeeze = FALSE) %>% 
      filter(tall %in% model.periods.from2020) %>%
      filter(all_regi == reg) %>%
      filter(rlf == "1") %>% 
      filter(all_te %in% names(remind.tech.mapping.narrow)) %>%
      mutate(value = value * 1e3) %>% #TW->GW
      select(period = tall, tech = all_te, rlf, value) %>% 
      revalue.levels(tech = remind.tech.mapping.narrow) %>%
      dplyr::group_by(period, tech, rlf) %>%
      dplyr::summarise( value = sum(value) , .groups = 'keep' ) %>% 
      dplyr::ungroup(period, tech, rlf) %>% 
      mutate(tech = factor(tech, levels=rev(unique(remind.tech.mapping.narrow))))%>% 
      mutate(iteration = it, model = "REMIND")
    
    out.remind.capacity <- rbind(out.remind.capacity, remind.capacity)
  }
  
  
# Data preparation (DIETER) -----------------------------------------------
out.dieter.cap.data <- NULL
out.remind.capfac <- NULL
out.dieter.peak.demand <- NULL
out.dieter.capfac <- NULL

if (length(dieter.files) != 0) {
  
  for (i in 1:length(dieter.files)){
    # i=22
    it <- as.numeric(str_extract(dieter.files[i], "[0-9]+"))
    remind.real.capfac <- file.path(outputdir, dieter.files.report[i]) %>% 
      read.gdx("report_tech", squeeze = F) %>% 
      select(model = X..1, period = X..2, variable = X..4, tech = X..5, value) %>% 
      filter(variable %in% c("REMIND real CapFac (%)")) %>% 
      revalue.levels(tech = dieter.tech.mapping) %>%
      mutate(tech = factor(tech, levels=rev(unique(dieter.tech.mapping))))%>% 
      mutate(iteration = it, model = "REMIND")
    
    dieter.cap.data <- file.path(outputdir, dieter.files[i]) %>% 
      read.gdx("p32_report4RM", factor = FALSE, squeeze = FALSE) %>%
      select(period = X..1, tech = X..3, variable=X..4, value)  %>%
      filter(period %in% model.periods.from2020) %>%
      filter(tech %in% names(dieter.tech.mapping)) %>%
      filter(!tech %in% names(dieter.storage.mapping)) %>% 
      filter(variable %in% c("capacity")) %>%
      revalue.levels(tech = dieter.tech.mapping) %>%
      mutate(tech = factor(tech, levels=rev(unique(dieter.tech.mapping)))) %>% 
      mutate(iteration = it, model = "DIETER")
    
    dieter.sto.cap.data <- file.path(outputdir, dieter.files[i]) %>% 
      read.gdx("p32_report4RM", factor = FALSE, squeeze = FALSE) %>%
      select(period = X..1, tech = X..3, variable=X..4, value) %>%
      filter(period %in% model.periods.from2020) %>%
      filter(tech %in% names(dieter.storage.mapping)) %>% 
      filter(variable %in% c("sto_P_capacity")) %>%
      revalue.levels(tech = dieter.storage.mapping) %>%
      mutate(tech = factor(tech, levels=rev(unique(dieter.storage.mapping)))) %>% 
      mutate(iteration = it, model = "DIETER", variable = "capacity") 
    
    dieter.cap.data <- list(dieter.cap.data, dieter.sto.cap.data) %>%
      reduce(full_join)
      
    dieter.peak.demand<- file.path(outputdir, dieter.files.report[i]) %>% 
      read.gdx("report", squeeze = F) %>% 
      select(model = X..1, period = X..2, variable = X..4, value) %>% 
      filter(variable %in% c("peak residual demand (GW)"))  %>% 
      mutate(iteration = it, model = "DIETER")%>% 
      select(iteration,period, model, value) %>% 
      mutate(var = "peak hourly residual demand")
    
    dieter.real.capfac <-
      file.path(outputdir, dieter.files.report[i]) %>% 
      read.gdx("report_tech", squeeze = F) %>% 
      select(model = X..1, period = X..2, variable = X..4, tech = X..5, value) %>% 
      filter(variable %in% c("DIETER real avg CapFac (%)")) %>% 
      revalue.levels(tech = dieter.tech.mapping) %>%
      mutate(tech = factor(tech, levels=rev(unique(dieter.tech.mapping))))%>% 
      mutate(iteration = it, model = "DIETER")
    
    out.remind.capfac <- rbind(out.remind.capfac,remind.real.capfac)
    out.dieter.cap.data <- rbind(out.dieter.cap.data, dieter.cap.data)
    out.dieter.peak.demand <- rbind(out.dieter.peak.demand, dieter.peak.demand)
    out.dieter.capfac <- rbind(out.dieter.capfac,dieter.real.capfac)
}
  
  out.dieter.capacity <- out.dieter.cap.data %>%
    filter(variable == "capacity") %>%
    mutate(value = value / 1e3) %>% # MW -> GW
    select(period, tech, value, iteration) %>% 
    dplyr::group_by(period,tech) %>%
    complete(iteration = iteration.list, fill = list(value = 0)) %>%
    dplyr::ungroup(period,tech)
  
}

# Plotting ----------------------------------------------------------------
##################################################################################################
swlatex(sw, paste0("\\section{Capacities}"))

for(year_toplot in model.periods){
  # year_toplot = 2035
  
  if(year_toplot >= 2020){
    
  plot.remind.capacity <- out.remind.capacity %>% 
    filter(period == year_toplot)
  
  if (length(dieter.files) != 0) {
    plot.remind.peak.demand <- out.remind.peak.demand %>% 
      filter(period == year_toplot)
    
    plot.remind.capfac <- out.remind.capfac %>% 
      filter(period == year_toplot) 
    
    plot.dieter.peak.demand <- out.dieter.peak.demand%>% 
      filter(period == year_toplot)
  }
  
  secAxisScale1 = max(plot.remind.capacity$value) / 100
  #get max value
  df.maxval<- plot.remind.capacity %>% 
    dplyr::group_by(period, rlf, iteration, model) %>%
    dplyr::summarise( value = sum(value) , .groups = 'keep' ) %>% 
    dplyr::ungroup(period, rlf, iteration, model) 
  
  ymax = max(df.maxval$value) * 1.1
  
swlatex(sw, paste0("\\subsection{Capacities in ", year_toplot, "}"))
  
  p1 <- ggplot() +
    geom_area(data = plot.remind.capacity, aes(x = iteration, y = value, fill = tech), size = 1.2, alpha = 0.5) +
    scale_y_continuous(sec.axis = sec_axis(~./secAxisScale1, name = "CF (%)"))+
    scale_fill_manual(name = "Technology", values = color.mapping.cap) +
    xlab("iteration") + ylab(paste0("capacity", "(GW)")) +
    ggtitle(paste0("REMIND: ", reg, " ", year_toplot))+
    coord_cartesian(xlim = c(0, max(plot.remind.capacity$iteration)+1),ylim = c(0, ymax)) +
    theme(legend.title = element_blank()) 
  
  if (length(dieter.files) != 0) {
    p1 <- p1 + 
      geom_line(data = plot.remind.peak.demand, aes(x = iteration, y = value, color = var), size = 1.2, alpha = 2,linetype="dotted") 
  }
  
  if ((CAPwith_CF != 0) & (length(dieter.files) != 0)) {
    p1 <- p1 + 
      geom_line(data = plot.remind.capfac, aes(x = iteration, y = value*secAxisScale1, color = tech), size = 1.2, alpha = 1)  +
      scale_color_manual(name = "Technology", values = color.mapping.capfac.line) 
  }
  
  if ((CAPwith_CF == 0) & (length(dieter.files) != 0)) {
    p1 <- p1 + 
      scale_color_manual(name = "var", values = color.mapping.cap.line)
  }
  
  if (length(dieter.files) != 0) {
  plot.dieter.capacity <- out.dieter.capacity %>%
    filter(period == year_toplot)
  
  plot.dieter.capfac <- out.dieter.capfac %>%
      filter(period == year_toplot)

  secAxisScale2 = max(plot.dieter.capacity$value) / 100
  
    p2<-ggplot() +
      geom_area(data = plot.dieter.capacity, aes(x = iteration, y = value, fill = tech), size = 1.2, alpha = 0.5) +
      geom_line(data = plot.dieter.peak.demand, aes(x = iteration, y = value, color = var), size = 1.2, alpha = 2, linetype="dotted") +
      scale_y_continuous(sec.axis = sec_axis(~./secAxisScale2, name = paste0("CF", "(%)")))+
      scale_fill_manual(name = "Technology", values = color.mapping.cap) +
      xlab("iteration") + ylab(paste0("Capacity (GW)")) +
      coord_cartesian(xlim = c(0, max(plot.dieter.capacity$iteration)),ylim = c(0, ymax))+
      ggtitle(paste0("DIETER: ", reg, " ", year_toplot)) +
      theme(legend.title = element_blank()) 
  }
  
  grid.newpage()
  
  if ((CAPwith_CF != 0) & (length(dieter.files) != 0)) {
    p2 <- p2 + geom_line(data = plot.dieter.capfac, aes(x = iteration, y = value*secAxisScale2, color = tech), size = 1.2, alpha = 1)+
      scale_color_manual(name = "Technology", values = color.mapping.capfac.line) }
  
  if ((CAPwith_CF == 0) & (length(dieter.files) != 0)) {
    p2 <- p2 + 
      scale_color_manual(name = "var", values = color.mapping.cap.line)
  }
  
  
  if ((length(dieter.files) != 0) ) {
    p <- arrangeGrob(rbind(ggplotGrob(p1), ggplotGrob(p2)))
  } else { p<-p1 }
  
  swfigure(sw,grid.draw,p)
  if (save_png == 1){
    if (length(dieter.files) != 0) {  
    
    ggsave(filename = paste0(outputdir, "/DIETER/CAP_", year_toplot, ".png"),  p,  width = 12, height =12, units = "in", dpi = 120)
    }
    else { 
    ggsave(filename = paste0(outputdir, "/DIETER/CAP_", year_toplot, ".png"),  p,  width = 12, height =6, units = "in", dpi = 120) }
  }
}

  }

##################################################################################################
swlatex(sw, "\\subsection{Capacities last iteration - double bar plot}")


    plot.remind.capacity <- out.remind.capacity %>% 
      filter(period %in% model.periods.from2020.till2100) %>% 
      filter(iteration == max(out.remind.capacity$iteration)) %>% 
      select(period,tech,value) %>% 
      filter(!tech %in% dieter.storage.mapping)%>%
      mutate(period = as.numeric(period)) 
    
    if ((length(dieter.files) != 0) ) {
      plot.dieter.capacity.stor <- out.dieter.capacity %>%
        mutate(period = as.numeric(period))%>%
        filter(iteration == max(out.remind.capacity$iteration)) %>% 
        select(period,tech,value) %>% 
        filter(period %in% model.periods.from2020.till2100) %>% 
        filter(tech %in% dieter.storage.mapping)
      
      plot.dieter.capacity.h2stor2 <- plot.dieter.capacity.stor %>% 
        filter(tech == "Electrolyzers for long-term storage") %>% 
        mutate(tech = "Hydrogen turbine")  
      
      plot.remind.capacity.wDIETERstorage <-list(plot.remind.capacity,
                                                 plot.dieter.capacity.stor,
                                                 plot.dieter.capacity.h2stor2
      ) %>% 
        reduce(full_join) 
      
      
      plot.remind.capacity.wDIETERstorage <- plot.remind.capacity.wDIETERstorage %>% 
        mutate(tech = factor(tech, levels=rev(unique(c("Hydrogen turbine", dieter.tech.mapping,"Electrolyzers for long-term storage"))))) %>% 
        mutate(model="REMIND")
      
      plot.remind.capacity.wDIETERstorage2 <- plot.remind.capacity.wDIETERstorage %>% 
        mutate(period = as.numeric(as.character(period)) - 1) 
        
      plot.dieter.capacity <- out.dieter.capacity %>%
        mutate(period = as.numeric(as.character(period))) %>% 
        filter(period %in% model.periods.from2020.till2100) %>% 
        filter(iteration == max(out.dieter.capacity$iteration)) %>% 
        select(-iteration) %>% 
        full_join(plot.dieter.capacity.h2stor2)%>% 
        mutate(tech = factor(tech, levels=rev(unique(c(dieter.tech.mapping,"Hydrogen turbine","Electrolyzers for long-term storage")))))%>% 
        mutate(model="DIETER") 
        
      plot.dieter.capacity2 <- plot.dieter.capacity %>% 
        mutate(period = as.numeric(as.character(period)) + 1) 
      
    }
    
      p<-ggplot() +
        geom_bar(data = plot.dieter.capacity2, aes(x=period, y=value, fill=tech, linetype=model), colour = "black", stat="identity",position="stack", width=1.5) + 
        geom_bar(data = plot.remind.capacity.wDIETERstorage2, aes(x=period, y=value, fill=tech, linetype=model), colour = "black", stat="identity",position="stack", width=1.5) + 
        scale_fill_manual(name = "Technology", values = color.mapping.cap) +
        scale_linetype_manual(name = "model", values = linetype.map) +
        guides(linetype = guide_legend(override.aes = list(fill = NA
                                                           , col = "black"))) +
        xlab("Time") + ylab(paste0("Capacity (GW)")) +
        ggtitle(paste0(reg)) +
        theme(legend.title = element_blank()) 
  
  swfigure(sw,print,p)
  if (save_png == 1){
    ggsave(filename = paste0(outputdir, "/DIETER/CAP_doublebar_time.png"),  p,  width = 10, height = 4.5, units = "in", dpi = 120)
  }
  


##################################################################################################
swlatex(sw, "\\subsection{Capacities over time (last iteration)}")



if ((length(dieter.files) == 0) ) {
  plot.remind.capacity.wDIETERstorage<-plot.remind.capacity
}
  
p.cap1<-ggplot() +
  geom_area(data = plot.remind.capacity.wDIETERstorage, aes(x = period, y = value, fill = tech), size = 1.2, alpha = 0.5) +
  scale_fill_manual(name = "Technology", values = color.mapping.cap) +
  theme(legend.position="none") +
  theme(axis.text=element_text(size=10), axis.title=element_text(size= 15, face="bold"),strip.text = element_text(size=13)) +
  xlab("Time") + ylab("Capacity (GW)") +
  ggtitle(paste0("REMIND last iteration: ", reg)) +
  theme(plot.title = element_text(size = 15, face = "bold"))

if (length(dieter.files) != 0) {

p.cap2<-ggplot() +
    geom_area(data = plot.dieter.capacity %>% filter(period %in% model.periods.till2100), aes(x = as.numeric(period), y = value, fill = tech), size = 1.2, alpha = 0.5) +
    scale_fill_manual(name = "Technology", values = color.mapping.cap) +
  theme(legend.position="bottom", legend.direction="horizontal", legend.title = element_blank(),legend.text = element_text(size=13)) +
  theme(axis.text=element_text(size=15), axis.title=element_text(size= 15, face="bold"),strip.text = element_text(size=13)) +
    xlab("Time") + ylab("Capacity (GW)") +
    ggtitle(paste0("DIETER last iteration: ", reg))+
  theme(legend.position="bottom", legend.direction="horizontal", legend.title = element_blank(),legend.text = element_text(size=10))+
  theme(plot.title = element_text(size = 15, face = "bold"))

}

grid.newpage()
if (length(dieter.files) != 0) {
  p <- arrangeGrob(rbind(ggplotGrob(p.cap1), ggplotGrob(p.cap2)))
} else { p<-p.cap1 }

swfigure(sw,grid.draw,p)

if (save_png == 1){
  if (length(dieter.files) != 0) {
  ggsave(filename = paste0(outputdir, "/DIETER/CAP_time.png"),  p,  width = 12, height =15, units = "in", dpi = 120)
  }else { 
  ggsave(filename = paste0(outputdir, "/DIETER/CAP_time.png"),  p,  width = 12, height =6, units = "in", dpi = 120) }
}
  
##################################################################################################
if (length(dieter.files) != 0) {
swlatex(sw, paste0("\\section{Capacity factors}"))

for(year_toplot in model.periods.from2020){
  plot.remind.capfac <- out.remind.capfac %>% 
    filter(period == year_toplot)
  
  plot.dieter.capfac <- out.dieter.capfac %>% 
    filter(period == year_toplot) 
  
  swlatex(sw, paste0("\\subsection{Capacity factors in ", year_toplot, "}"))
  
  p <- ggplot() + 
    geom_line(data=plot.remind.capfac, aes(x=iteration, y=value, color=variable, linetype = model)) + 
    geom_line(data=plot.dieter.capfac, aes(x=iteration, y=value, color=variable, linetype = model)) +
    scale_color_manual(name = "variable", values = color.mapping.cf)+
    theme(legend.position="bottom", legend.direction="horizontal", legend.title = element_blank(),legend.text = element_text(size=7)) +
    xlab("Iteration") + 
    ylab("Capacity factor") + 
    facet_wrap(~tech, nrow=3)
  
  swfigure(sw,print,p)
  if (save_png == 1){
  ggsave(filename = paste0(outputdir, "/DIETER/CF_", year_toplot, ".png"),  p,  width = 6, height =5, units = "in", dpi = 120)
  }
}

##################################################################################################
swlatex(sw, "\\subsection{Capacity factors over time (last iteration): detailed}")

data.capfac <-
  file.path(outputdir, dieter.files.report[length(dieter.files.report)]) %>% 
  read.gdx("report_tech", squeeze = F) %>% 
  select(model = X..1, period = X..2, variable = X..4, tech = X..5, value) %>% 
  filter(variable %in% capfac.detail.report.dieter) %>% 
  revalue.levels(tech = dieter.tech.mapping) %>%
  mutate(tech = factor(tech, levels=rev(unique(dieter.tech.mapping))))
  
p <- ggplot() +
  geom_line(data = data.capfac, aes(x = as.numeric(period), y = value, color = variable, linetype = model), size = 1.2, alpha = 1) +
  scale_color_manual(name = "variable", values = color.mapping.cf.detail) +
  theme(axis.text=element_text(size=10), axis.title=element_text(size=10,face="bold")) +
  theme(legend.position="bottom", legend.direction="horizontal", legend.title = element_blank(),legend.text = element_text(size=10)) +
  facet_wrap(~tech, nrow = 3)+
  xlab("Time") +
  ylab("Capacity factor")

swfigure(sw,print,p)

if (save_png == 1){
  ggsave(filename = paste0(outputdir, "/DIETER/CF_compare_time.png"),  p,  width = 15, height =8, units = "in", dpi = 120)
}

if (length(dieter.files) != 0) {
for (i in c(start_i + 1, start_i + 5, start_i + 10,maxiter - 1)){
  # i = 27
  plot.remind.cap.snap <- out.remind.capacity %>% 
    filter(iteration == i) %>% 
    filter(period <2110) %>%
    mutate(period = as.numeric(period)) %>% 
    dplyr::rename(remind_cap = value)
  
  plot.dieter.cap.snap <- out.dieter.capacity %>%
    filter(iteration == i) %>%
    filter(period <2110) %>%
    mutate(period = as.numeric(period)) %>%
    dplyr::rename(dieter_cap = value)%>%
    filter(!tech %in% dieter.storage.mapping)
  
  plot.cap.diff <- list(plot.remind.cap.snap, plot.dieter.cap.snap) %>%
    reduce(full_join) %>%
    mutate(delta_cap = remind_cap - dieter_cap)
  
  p <-ggplot() +
    geom_bar(data = plot.cap.diff , aes(x = period, y = delta_cap, fill = tech, label = delta_cap),  alpha = 0.5, stat = "identity") +
    geom_label(size = 3, position = position_stack(vjust = 0.5)) +
    scale_fill_manual(name = "Technology", values = color.mapping)+
    theme(axis.text=element_text(size=10), axis.title=element_text(size= 10,face="bold")) +
    xlab("Time") + ylab("Capacity (GW)") +
    ggtitle("Capacity difference REMIND - DIETER")+
    theme(legend.position="bottom", legend.direction="horizontal", legend.title = element_blank()) +
    theme(aspect.ratio = .5)
  
  swfigure(sw, grid.draw, p)
  if (save_png == 1){
    ggsave(filename = paste0(outputdir, "/DIETER/deltaCapacity_time_i", i, ".png"),  p,  width = 8, height =7, units = "in", dpi = 120)
  }

}
}
}

