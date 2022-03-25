# any start rules here will be merged with the main varnish conf
# 

if (req.http.user-agent ~ "(?i)Android") {
    hash_data("10");
} elsif (req.http.user-agent ~ "(?i)iP(hone|od)") {
    hash_data("10");
} elsif (req.http.user-agent ~ "(?i)Tablet") {
    hash_data("10");
} elsif (req.http.user-agent ~ "(?i)iPad") {
    hash_data("10");
}
