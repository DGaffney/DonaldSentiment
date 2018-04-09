require "cgi"
require "base64"
require "openssl"
require "uri"
require "net/http"
require "net/https"
require "rexml/document"
require "time"
class AlexaRank
  SERVICE_HOST = "awis.amazonaws.com"
  SERVICE_ENDPOINT = "awis.us-west-1.amazonaws.com"
  SERVICE_PORT = 443
  SERVICE_URI = "/api"
  SERVICE_REGION = "us-west-1"
  SERVICE_NAME = "awis"

  def getSignatureKey(key, dateStamp, regionName, serviceName)
    kDate    = OpenSSL::HMAC.digest('sha256', "AWS4" + key, dateStamp)
    kRegion  = OpenSSL::HMAC.digest('sha256', kDate, regionName)
    kService = OpenSSL::HMAC.digest('sha256', kRegion, serviceName)
    kSigning = OpenSSL::HMAC.digest('sha256', kService, "aws4_request")
    kSigning
  end

  # escape str to RFC 3986
  def escapeRFC3986(str)
    return URI.escape(str,/[^A-Za-z0-9\-_.~]/)
  end

  def get_score(url)
    access_key_id = SETTINGS["aws_key"]
    secret_access_key = SETTINGS["aws_secret"]
    site = url
    action = "UrlInfo"
    responseGroup = "Rank,LinksInCount,RankByCountry,UsageStats,AdultContent,Categories"
    timestamp = ( Time::now ).utc.strftime("%Y%m%dT%H%M%SZ")
    datestamp = ( Time::now ).utc.strftime("%Y%m%d")

    headers = {
      "host"        => SERVICE_ENDPOINT,
      "x-amz-date"  => timestamp
    }

    query = {
      "Action"           => action,
      "ResponseGroup"    => responseGroup,
      "Url"              => site
    }

    query_str = query.sort.map{|k,v| k + "=" + escapeRFC3986(v.to_s())}.join('&')
    headers_str = headers.sort.map{|k,v| k + ":" + v}.join("\n") + "\n"
    headers_lst = headers.sort.map{|k,v| k}.join(";")
    payload_hash = Digest::SHA256.hexdigest ""
    canonical_request = "GET" + "\n" + SERVICE_URI + "\n" + query_str + "\n" + headers_str + "\n" + headers_lst + "\n" + payload_hash
    algorithm = "AWS4-HMAC-SHA256"
    credential_scope = datestamp + "/" + SERVICE_REGION + "/" + SERVICE_NAME + "/" + "aws4_request"
    string_to_sign = algorithm + "\n" +  timestamp + "\n" +  credential_scope + "\n" + (Digest::SHA256.hexdigest canonical_request)
    signing_key = getSignatureKey(secret_access_key, datestamp, SERVICE_REGION, SERVICE_NAME)
    signature=OpenSSL::HMAC.hexdigest('sha256', signing_key, string_to_sign)
    authorization_header = algorithm + " " + "Credential=" + access_key_id + "/" + credential_scope + ", " +  "SignedHeaders=" + headers_lst + ", " + "Signature=" + signature;

    url = "https://" + SERVICE_HOST + SERVICE_URI + "?" + query_str
    uri = URI(url)
    puts "Making request to:\n#{url}\n\n"
    req = Net::HTTP::Get.new(uri)
    req["Accept"] = "application/xml"
    req["Content-Type"] = "application/xml"
    req["x-amz-date"] = timestamp
    req["Authorization"] = authorization_header

    res = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https') {|http|
      http.request(req)
    }

    xml  = REXML::Document.new( res.body )
    response = Crack::XML.parse(xml.to_s)
    meat = response["aws:UrlInfoResponse"]["aws:Response"]["aws:UrlInfoResult"]["aws:Alexa"]
    {
      page_views_per_million: (meat["aws:TrafficData"]["aws:UsageStatistics"]["aws:UsageStatistic"][0]["aws:PageViews"]["aws:PerMillion"]["aws:Value"].gsub(",", "") rescue nil).to_i,
      page_rank: (meat["aws:TrafficData"]["aws:Rank"] rescue nil).to_i,
      tags: (meat["aws:Related"]["aws:Categories"]["aws:CategoryData"][0]["aws:AbsolutePath"].split("/") rescue []),
      inbound_links: (meat["aws:ContentData"]["aws:LinksInCount"] rescue nil).to_i,
      country_rank: (meat["aws:TrafficData"]["aws:RankByCountry"]["aws:Country"].select{|x| x["Code"] == "US"}.first["aws:Rank"] rescue nil).to_i,
      proportion_us: (meat["aws:TrafficData"]["aws:RankByCountry"]["aws:Country"].select{|x| x["Code"] == "US"}.first["aws:Contribution"]["aws:PageViews"].gsub("%", "") rescue nil).to_f/100.0,
      domain: site
    }
  end
end
