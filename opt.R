a = 0.1
b = 0.04
alpha = 3/2
beta = 4
t0 = rep(0, num.countries)
peak.cases = rep(1, num.countries)

p.init = apply(deaths.m, 1, max, na.rm = TRUE)
t0.init = apply(deaths.m, 1, which.max)
x.init = c(t0.init, p.init)

deaths.init = compute.deaths(
    num.countries,
    num.dates,
    rep(a, num.countries),
    rep(b, num.countries),
    alpha,
    beta,
    t0.init,
    p.init
)

o.init.dt = rbindlist(list(
    pred=as.data.table(melt(deaths.init)),
    obs=as.data.table(melt(deaths.m))
), idcol = 'what')



compute.deaths = function(
    num.countries,
    num.dates,
    a,
    b,
    alpha,
    beta,
    t0,
    p
) {
  # decay constants are per country
  assert(length(a) == num.countries)
  assert(length(b) == num.countries)
  # incubation period constants
  assert(length(alpha) == 1)
  assert(length(beta) == 1)
  # time of lockdown
  assert(length(t0) == num.countries)
  # peak cases
  assert(length(p) == num.countries)

  # vectors to arrays
  a = replicate(num.dates, a)
  b = replicate(num.dates, b)
  t0 = replicate(num.dates, t0)
  p = replicate(num.dates, p)

  # make time matrix
  t = t(replicate(num.countries, seq(num.dates)))

  # proper matrix product
  idx = (t > t0)
  gam.1 = (t-t0) * (1 + a * beta) / beta
  gam.1[idx] = sapply(gam.1[idx], incgam, a=alpha)

  gam.2 = (t-t0) * (1 - b * beta) / beta
  gam.2[idx] = sapply(gam.2[idx], incgam, a=alpha)

  gam.a = gamma(alpha)
  gam.a = matrix(gam.a, num.countries, num.dates)

  est.deaths = matrix(0, num.countries, num.dates)
  est.deaths[!idx] = (exp(a * (t - t0)) / (1 + a * beta)^alpha)[!idx]
  part.1 = exp(a * (t - t0)) * (1 + a * beta)^(-alpha) * gam.1 / gam.a
  part.2 = exp(b * (t0 - t)) * (1 - b * beta)^(-alpha) * (1 - gam.2 / gam.a)
  est.deaths[idx] = part.1[idx] + part.2[idx]
  est.deaths = est.deaths * p
  return(est.deaths)
}

unpack.params = function(x) {
  t0 = head(x, num.countries)
  x = tail(x, -num.countries)

  p = head(x, num.countries)
  x = tail(x, -num.countries)

  assert(length(x) == 0)
  return(list(t0 = t0, p = p))
}

f = function(x) {
  params = unpack.params(x)
  t0 = params$t0
  p = params$p

  # will go away when we pipe a and b as optimization parameters
  a = rep(a, num.countries)
  b = rep(b, num.countries)



  est.deaths = compute.deaths(
      num.countries,
      num.dates,
      a,
      b,
      alpha,
      beta,
      t0,
      p
  )
  d = (est.deaths - deaths.m) # / deaths.m
  return(sqrt(mean(d * d, na.rm = TRUE)))
}

sol = optim(x.init, f, control=list(maxit=1000))


params = unpack.params(sol$par)
t0.sol = params$t0
p.sol = params$p


deaths.sol= compute.deaths(
    num.countries,
    num.dates,
    rep(a, num.countries),
    rep(b, num.countries),
    alpha,
    beta,
    t0.sol,
    p.sol
)

o.dt = rbindlist(list(
    init=as.data.table(melt(deaths.init)),
    sol=as.data.table(melt(deaths.sol)),
    obs=as.data.table(melt(deaths.m))
), idcol = 'what')
p = ggplot(o.dt, aes(x=Var2, y=value, color=what)) + geom_step() + facet_wrap(~Var1)
print(p)
