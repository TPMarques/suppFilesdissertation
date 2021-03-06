rm(list=ls())
#load packages
library(readxl)
library(dplyr)
library(tidyr)
library(BASS)
library(coda)
library(freeknotsplines)
library(convRJMCMC)

#set workspace to data directory
#diretorio onde estao os dados
setwd("C:/Users/Tiago/Drive UNESP/Dissertacao/Ricardo_2015/Analises")

#read excel
data<-read_xlsx("dados1.xlsx")
data<-data.frame(gather(data,key="tempo",value="temperatura",paste(seq(0,600,by=30))))
P5_c2<-filter(data,data$Probe=="PROBE5",data$Ciclo==2)

fnP5_c2d3<-fit.search.numknots(as.numeric(P5_c2$tempo), as.numeric(P5_c2$temperatura), degree=3, minknot = 1, maxknot = 10, seed = 949)

set.seed(219)
#BASS PROBE5 CICLO 1
{
  Chain1_P5_c2<-bass(xx=as.numeric(P5_c2$tempo),
                     y=as.numeric(P5_c2$temperatura),degree=3,thin=100,nmcmc=1010000,nburn = 10000)
  Chain2_P5_c2<-bass(xx=as.numeric(P5_c2$tempo),
                     y=as.numeric(P5_c2$temperatura),degree=3,thin=100,nmcmc=1010000,nburn = 10000)
  Chain3_P5_c2<-bass(xx=as.numeric(P5_c2$tempo),
                     y=as.numeric(P5_c2$temperatura),degree=3,thin=100,nmcmc=1010000,nburn = 10000)
}

#salvar sessao do R no arquivo P5_c2.RData

#diretorio onde foi salvo o arquivo P5_c2.RData
setwd("C:/Users/Tiago/Drive UNESP/Dissertacao/Ricardo_2015/Defesa")

load("P5_c2.RData")


###Definicao funcoes plotagem de curvas e residuos
#Plotar curva ajustada e intervalos de credibilidade 95% para BASS
pred_line<-function(chain1,chain2,chain3,yourcolor="black",lw=1,lt1=1,lt2=3,mcmcit=1:length(chain1$s2)){
  #Plotar curva
  lines(seq(0,600,by=1),colMeans(rbind(
    predict(chain1,data.frame(Tempo=seq(0,600,by=1)),mcmc.use=mcmcit),
    predict(chain2,data.frame(Tempo=seq(0,600,by=1)),mcmc.use=mcmcit),
    predict(chain3,data.frame(Tempo=seq(0,600,by=1)),mcmc.use=mcmcit)
  )
  
  )
  ,col=yourcolor,lwd=lw,lty=lt1)
  #Criar previs�es m�dias para cada cadeia
  yn_di_ubt<-predict(chain1,seq(0,600,by=1),mcmc.use=mcmcit)
  yn_di_ubta<-predict(chain2,seq(0,600,by=1),mcmc.use=mcmcit)
  yn_di_ubtb<-predict(chain3,seq(0,600,by=1),mcmc.use=mcmcit)
  #Criar multiplicador
  mult <- 1.96 * sqrt(chain1$s2[mcmcit])
  multa <- 1.96 * sqrt(chain2$s2[mcmcit])
  multb <- 1.96 * sqrt(chain3$s2[mcmcit])
  #Criar limites inferiores
  q1 <- apply(yn_di_ubt - mult, 2, quantile, probs = .025)
  q1a <- apply(yn_di_ubta - multa, 2, quantile, probs = .025)
  q1b <- apply(yn_di_ubtb - multb, 2, quantile, probs = .025)
  #Criar limites superiores
  q2 <- apply(yn_di_ubt + mult, 2, quantile, probs = .975)
  q2a <- apply(yn_di_ubta + multa, 2, quantile, probs = .975)
  q2b <- apply(yn_di_ubtb + multb, 2, quantile, probs = .975)
  #Plotar limites inferiores
  lines(seq(0,600,by=1),colMeans(rbind(q1,q1a,q1b)),lty=lt2,col=yourcolor,lwd=lw)
  #Plotar limites superiores
  lines(seq(0,600,by=1),colMeans(rbind(q2,q2a,q2b)),lty=lt2,col=yourcolor,lwd=lw)
}

#Plotar curva ajustada e intervalos de confian�a 95% para freeknotsplines
fpred_line<-function(freeknotobj,dadosajuste,yourcolor="purple",lt1=1,lt2=3,lw=1){
  #Plotar curva ajustada
  lines(seq(0,600,by=1),fitted(freeknotobj,seq(0,600,by=1)),col=yourcolor,lty=lt1,lwd=lw)
  #Criar previs�o �dia
  fnp_fitted<-fitted(freeknotobj,seq(0,600,by=1))
  #Criar multiplicador
  mult <- 1.96 * sqrt(var(fitted(freeknotobj,as.numeric(dadosajuste$tempo))-as.vector(as.numeric(dadosajuste$temperatura))))
  #Criar limite inferior
  q1 <- apply(fnp_fitted - as.numeric(mult), 1, quantile, probs = .025)
  #Criar limite superior
  q2 <- apply(fnp_fitted + as.numeric(mult), 1, quantile, probs = .975)
  #Plotar limite inferior
  lines(seq(0,600,by=1),q1,lty=lt2,col=yourcolor,lwd=lw)
  #Plotar limite superior
  lines(seq(0,600,by=1),q2,lty=lt2,col=yourcolor,lwd=lw) 
}

#Criar objeto de class BASSresiduals de res�duos para BASS com 3 cadeias
BASSresiduals<-function(chain1,chain2,chain3,x_data,y_data,mcmcit=1:length(chain1$s2)){
  #Criar vetor de y estimados para 3 cadeias
  y_est<-colMeans(rbind(
    predict(chain1,data.frame(Tempo=as.numeric(x_data)),mcmc.use=mcmcit),
    predict(chain2,data.frame(Tempo=as.numeric(x_data)),mcmc.use=mcmcit),
    predict(chain3,data.frame(Tempo=as.numeric(x_data)),mcmc.use=mcmcit)))
  #Res�duos
  residuals<-as.numeric(y_data)-as.numeric(y_est) 
  #Criar conjunto de dados de nome residuals com X, Y observado, Y estimado e res�duos
  residuals<-data.frame(matrix(cbind(as.numeric(x_data),as.numeric(y_data),y_est,residuals),ncol=4))
  colnames(residuals)<-c("X","Y Observado","Y Estimado", "Res�duos")
  #Atribuir class: BASSresiduals a objeto
  attr(residuals,'class')<-'BASSresiduals'
  return(residuals)
}

#Criar fun��o plot para objetos da class BASSresiduals
plot.BASSresiduals<-function(obj,bottomtext=NA){
  #Dividir gr�fico em 5 pain�is 4 grandes em matrix 2x2 em cima
  #1 pequeno em  baixo
  layout(matrix(c(1,2,5,3,4,5),nrow=3),heights = c(1, 1,0.1))
  par(cex.lab=1.5,cex.axis=1.5,cex.main=2,mar=c(5.1,5.1,4.1,2.1))
  plot(obj$X,obj$Res�duos,xlab="Tempo",ylab="Res�duo", main="Res�duo x Tempo")
  plot(obj$'Y Observado',obj$'Y Estimado',xlab="Temperatura Observada",ylab="Temperatura Estimada", main="Temperatura Estimada x Observada")
  abline(a=0,b=1)
  plot(obj$'Y Estimado',obj$Res�duo,xlab="Temperatura Estimada",ylab="Res�duo", main="Res�duo x Temperatura Estimada")
  qqPlot(obj$Res�duo,xlab="Quantis da Distribui��o Normal",
         ylab="Quantis da Amostra",main="Gr�fico Quantil-Quantil da Distribui��o Normal")
  par(fig=c(0,1,0,1),oma=c(0,0,0,0),mar=c(0,0,0,0),new=TRUE)
  plot(0,0,type="n",bty="n",xaxt="n",yaxt="n")
  text(0,-1,bottomtext,cex=1.5)
}

#Criar objeto de class fnsresiduals de res�duos para FNS
fnsresiduals<-function(fns_model,x_data,y_data){
  #Criar vetor de y estimados para 3 cadeias
  y_est<-fitted(fns_model)
  #Res�duos
  residuals<-residuals(fns_model)
  #Criar conjunto de dados de nome residuals com X, Y observado, Y estimado e res�duos
  residuals<-data.frame(matrix(cbind(as.numeric(x_data),as.numeric(y_data),y_est,residuals),ncol=4))
  colnames(residuals)<-c("X","Y Observado","Y Estimado", "Res�duos")
  #Atribuir class: BASSresiduals a objeto
  attr(residuals,'class')<-'fnsresiduals'
  return(residuals)
}

#Criar fun��o plot para objetos da class fnsresiduals
plot.fnsresiduals<-function(obj,bottomtext=NA){
  #Dividir gr�fico em 5 pain�is 4 grandes em matrix 2x2 em cima
  #1 pequeno em  baixo
  layout(matrix(c(1,2,5,3,4,5),nrow=3),heights = c(1, 1,0.1))
  par(cex.lab=1.5,cex.axis=1.5,cex.main=2,mar=c(5.1,5.1,4.1,2.1))
  plot(obj$X,obj$Res�duos,xlab="Tempo",ylab="Res�duo", main="Res�duo x Tempo")
  plot(obj$'Y Observado',obj$'Y Estimado',xlab="Temperatura Observada",ylab="Temperatura Estimada", main="Temperatura Estimada x Observada")
  abline(a=0,b=1)
  plot(obj$'Y Estimado',obj$Res�duo,xlab="Temperatura Estimada",ylab="Res�duo", main="Res�duo x Temperatura Estimada")
  qqPlot(obj$Res�duo,xlab="Quantis da Distribui��o Normal",
         ylab="Quantis da Amostra",main="Gr�fico Quantil-Quantil da Distribui��o Normal")
  par(fig=c(0,1,0,1),oma=c(0,0,0,0),mar=c(0,0,0,0),new=TRUE)
  plot(0,0,type="n",bty="n",xaxt="n",yaxt="n")
  text(0,-1,bottomtext,cex=1.5)
}
###

resultado_CZANOVA1<-CZ_ANOVA(c(Chain1_P5_c2$s2,Chain2_P5_c2$s2,Chain3_P5_c2$s2)
                             ,factor(c(rep(1,10000),rep(2,10000),rep(3,10000)))
                             ,c(Chain1_P5_c2$nbasis,Chain2_P5_c2$nbasis,Chain3_P5_c2$nbasis)
                             ,rep(seq(1,10000),3))

x11()
#Graficos de convergencia Castelloe e Zimmerman (2002)
#Pacote convRJMCMC (Marques e Tsunemi, 2021)
plot(resultado_CZANOVA1)

#Gr�ficos de Autocorrela��o

x11()
acf(Chain1_P5_c2$s2,main=NA,xlab="Atraso",ylab="Autocorrela��o")
acf(Chain2_P5_c2$s2,main=NA,xlab="Atraso",ylab="Autocorrela��o")
acf(Chain3_P5_c2$s2,main=NA,xlab="Atraso",ylab="Autocorrela��o")

#Grafico de tracos

x11()
traceplot(mcmc.list(mcmc(Chain1_P5_c2$s2),mcmc(Chain2_P5_c2$s2),mcmc(Chain3_P5_c2$s2)),
          xlab="Itera��es",ylab=expression(sigma**2))


#traceplot(mcmc.list(mcmc(Chain1_P5_c2$nbasis),mcmc(Chain2_P5_c2$nbasis),mcmc(Chain3_P5_c2$nbasis)))

barplot(table(Chain1_P5_c2$nbasis))
#,main = "Probe 5 Ciclo 2 (Cadeia 1)"
barplot(table(Chain2_P5_c2$nbasis))
#,main = "Probe 5 Ciclo 2 (Cadeia 2)"
barplot(table(Chain3_P5_c2$nbasis))
#,main = "Probe 5 Ciclo 2 (Cadeia 3)"

# #Gr�fico de Dispers�o
# x11()
# layout(matrix(c(1,2),nrow=2),heights = c(1,0.1))
# par(mar=c(5.1,5.1,4.1,2.1))
# ypmin<-1.1*min(P5_c2$temperatura)
# ypmax<-1.2*max(P5_c2$temperatura)
# plot(P5_c2$tempo,P5_c2$temperatura,xlab = "Tempo (s)",ylab = expression(paste("Temperatura (",degree,"C)",sep ="")),
#      ylim=c(ypmin,ypmax),pch=P5_c2$Vertebra)
# abline(h=-20,col="#A9A9A9",lty=5)
# pred_line(Chain1_P5_c2,Chain2_P5_c2,Chain3_P5_c2)
# fpred_line(fnP5_c2d3,P5_c2,yourcolor = "gray")
# par(mar=c(rep(0,4)))
# plot(0,0,type="n",bty="n",xaxt="n",yaxt="n")
# legend(-1,1,lty=c(1,3,1,3),col = c(1,1,"gray","gray"),
#        legend = c("Curva Ajustada BASS (M�dia a Posteriori)",
#                   "Intervalo de Credibilidade 95% (BASS)",
#                   "Curva Ajustada freeknotsplines",
#                   "Intervalo de Confian�a 95% (freeknotsplines)"),ncol=2)
# legend(0.25,1,pch=c(1,2,3,4,5,6),legend=c("1","2","3","4","5","6"),title="V�rtebra",ncol=6)
# #main="Gr�fico de Dispers�o Temperatura x Tempo (PROBE 5 Ciclo 2)"

#Gr�fico de dispersao no Cairo device
#direcionar a pasta onde serao salvos os resultados
setwd("C:/Users/Tiago/Drive UNESP/Dissertacao/Ricardo_2015/Defesa/CRIO")
library(Cairo)
#png("disp.png")
#("disp.png",width=842,height=595,dpi=72,units="pt")
CairoPDF("disp.pdf",width=11.7,height=8.3)
layout(matrix(c(1,2),nrow=2),heights = c(1,0.1))
par(mar=c(5.1,5.1,4.1,2.1))
ypmin<-1.1*min(P5_c2$temperatura)
ypmax<-1.2*max(P5_c2$temperatura)
plot(P5_c2$tempo,P5_c2$temperatura,xlab = "Tempo (s)",ylab = expression(paste("Temperatura (",degree,"C)",sep ="")),
     ylim=c(ypmin,ypmax),pch=P5_c2$Vertebra,yaxt="none")
axis(2,c(-40,-20,0,8,20,40))
abline(h=-20,col="#A9A9A9",lty=5)
abline(h=8,col="#A9A9A9",lty=5)
pred_line(Chain1_P5_c2,Chain2_P5_c2,Chain3_P5_c2)
fpred_line(fnP5_c2d3,P5_c2,yourcolor = "gray")
par(mar=c(rep(0,4)))
plot(0,0,type="n",bty="n",xaxt="n",yaxt="n")
legend(-1,1,lty=c(1,3,1,3),col = c(1,1,"gray","gray"),
       legend = c("Curva Ajustada BASS (M�dia a Posteriori)",
                  "Intervalo de Credibilidade 95% (BASS)",
                  "Curva Ajustada freeknotsplines",
                  "Intervalo de Confian�a 95% (freeknotsplines)"),ncol=2)
legend(0.6,1,pch=c(1,2,3,4,5,6),legend=c("1","2","3","4","5","6"),title="V�rtebra",ncol=6)
dev.off()
x11()
#Gr�fico densidades preditivas no Cairo device
#CairoPDF("preddens.pdf",width=11.7,height=8.3)
CairoPNG("preddens.png",width=842,height=595,dpi=72,units="pt")
layout(matrix(c(1,2),nrow=2),heights = c(1,0.1))
par(mar=c(5.1,5.1,4.1,2.1))
ypmin<-1.1*min(P5_c2$temperatura)
ypmax<-1.2*max(P5_c2$temperatura)
plot(P5_c2$tempo,P5_c2$temperatura,xlab = "Tempo (s)",
     ylab = expression(paste("Temperatura (",degree,"C)",sep ="")),
     ylim=c(ypmin,ypmax),pch=P5_c2$Vertebra,yaxt="none")
axis(2,c(-40,-20,0,8,20,40))
for(i in 1:10000){
  lines(seq(0,600,by=1),predict(Chain1_P5_c2,data.frame(Tempo=seq(0,600,by=1)),
                                mcmc.use=i),col="grey")
  lines(seq(0,600,by=1),predict(Chain2_P5_c2,data.frame(Tempo=seq(0,600,by=1)),
                                mcmc.use=i),col="grey")
  lines(seq(0,600,by=1),predict(Chain3_P5_c2,data.frame(Tempo=seq(0,600,by=1)),
                                mcmc.use=i),col="grey")
}
pred_line(Chain1_P5_c2,Chain2_P5_c2,Chain3_P5_c2)
par(mar=c(rep(0,4)))
plot(0,0,type="n",bty="n",xaxt="n",yaxt="n")
legend(-1,1,lty=c(1,3,1),col = c(1,1,"gray"),
       legend = c("Curva Ajustada BASS (M�dia a Posteriori)",
                  "Intervalo de Credibilidade 95% (BASS)",
                  "Densidades Preditivas"),ncol=2)
legend(0.6,1,pch=c(1,2,3,4,5,6),legend=c("1","2","3","4","5","6"),title="V�rtebra",ncol=6)
dev.off()

help("CairoPDF")

#Gr�ficos de Res�duos

library(car)

#freeknotsplines
fres<-fnsresiduals(fnP5_c2d3,P5_c2$tempo,P5_c2$temperatura)
x11()
plot(fres)

BASS
BASSres<-BASSresiduals(Chain1_P5_c2,Chain2_P5_c2,Chain3_P5_c2,P5_c2$tempo,P5_c2$temperatura)
plot(BASSres)

#barplot complexidade do modelo, n�mero de fun��es de base
x11()
barplot(table(c(Chain1_P5_c2$nbasis,Chain2_P5_c2$nbasis,Chain3_P5_c2$nbasis)))
