function colorize(r,g,b,s;
    factor = 5.0,
    offset = 0.0004,
    γ = 0.5)
#    fun(x) = x < offset ? 0.0 : tanh(factor*(x-offset)^γ)
    fun(x) = x < offset ? 0.0 : 0.5*tanh(factor*(x-offset)^γ) + 0.5*tanh(factor*(x-offset)^γ /2 )
    if s < 0.1
        R, G, B = N0f16.([fun(r), fun(g), fun(b)])
    else 
        mv = fun(mean([r,g,b])*1.5 - 0.5*maximum([r,g,b]))
        R, G, B = N0f16.([mv , mv, mv])
    end
    return RGB(R,G,B)
end 