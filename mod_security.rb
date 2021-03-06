class ModSecurity < Formula
  class CLTRequirement < Requirement
    fatal true
    satisfy { MacOS.version < :mavericks || MacOS::CLT.installed? }

    def message; <<-EOS.undent
      Xcode Command Line Tools required, even if Xcode is installed, on OS X 10.9 or
      10.10 and not using Homebrew httpd22 or httpd24. Resolve by running
        xcode-select --install
      EOS
    end
  end

  desc "Open Source Web application firewall"
  homepage "http://www.modsecurity.org/"
  url "https://github.com/SpiderLabs/ModSecurity/releases/download/v2.9.1/modsecurity-2.9.1.tar.gz"
  sha256 "958cc5a7a7430f93fac0fd6f8b9aa92fc1801efce0cda797d6029d44080a9b24"
  head "https://github.com/SpiderLabs/ModSecurity.git"

  bottle do
    cellar :any
    sha256 "d4c2b06ad033fe4263401c5e4e0b65bdee7770bc61ff19a34e5bd6ff168c545c" => :el_capitan
    sha256 "3d9437bf355784c5c63134de2602748e3ac6d4961eecb4c4a172f41e06edbd61" => :yosemite
    sha256 "5277e3a645a6de545f576140259dfd2fc4d17b9a2bd159a4b83d3ca4447bf200" => :mavericks
  end

  option "with-homebrew-apr", "Use Homebrew apr"
  option "with-homebrew-httpd22", "Use Homebrew Apache httpd 2.2"
  option "with-homebrew-httpd24", "Use Homebrew Apache httpd 2.4"

  deprecated_option "with-brewed-apr" => "with-homebrew-apr"
  deprecated_option "with-brewed-httpd22" => "with-homebrew-httpd22"
  deprecated_option "with-brewed-httpd24" => "with-homebrew-httpd24"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "apr-util" if build.with? "homebrew-apr"
  depends_on "httpd22" if build.with? "homebrew-httpd22"
  depends_on "httpd24" if build.with? "homebrew-httpd24"
  depends_on "libtool" => :build
  depends_on "pcre"
  depends_on CLTRequirement if build.without?("homebrew-httpd22") && build.without?("homebrew-httpd24")

  # Mavericks and older OS requires a more recent curl version than what's bundled
  if MacOS.version <= :mavericks
    depends_on "curl"
  end

  if build.with?("homebrew-apr") && (build.with?("homebrew-httpd22") || build.with?("homebrew-httpd24"))
    opoo "Ignoring --with-homebrew-apr: homebrew apr included in httpd22 and httpd24"
  end

  def apache_apxs
    if build.with? "homebrew-httpd22"
      %W[sbin bin].each do |dir|
        if File.exist?(location = "#{Formula["httpd22"].opt_prefix}/#{dir}/apxs")
          return location
        end
      end
    elsif build.with? "homebrew-httpd24"
      %W[sbin bin].each do |dir|
        if File.exist?(location = "#{Formula["httpd24"].opt_prefix}/#{dir}/apxs")
          return location
        end
      end
    else
      "/usr/sbin/apxs"
    end
  end

  def apache_configdir
    if build.with? "homebrew-httpd22"
      "#{etc}/apache2/2.2"
    elsif build.with? "homebrew-httpd24"
      "#{etc}/apache2/2.4"
    else
      "/etc/apache2"
    end
  end

  def install
    if build.with?("homebrew-httpd22") && build.with?("homebrew-httpd24")
      odie "Cannot build for http22 and httpd24 at the same time"
    end

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --with-pcre=#{Formula["pcre"].opt_prefix}
      --with-apxs=#{apache_apxs}
    ]

    if build.with?("homebrew-httpd22") || build.with?("homebrew-httpd24") || build.with?("homebrew-apr")
      args << "--with-apr=#{Formula["apr"].opt_prefix}"
      args << "--with-apu=#{Formula["apr-util"].prefix}/bin"
    else
      args << "--with-apr=/usr/bin"
      args << "--with-apu=/usr/bin"
    end

    # Mavericks and older OS requires a more recent curl version than what's bundled
    if MacOS.version <= :mavericks
      args << "--with-curl=#{Formula["curl"].opt_prefix}"
    end

    system "./autogen.sh"
    system "./configure", *args
    system "make"

    libexec.install "apache2/.libs/mod_security2.so"

    # Use Homebrew paths in the sample file
    inreplace "modsecurity.conf-recommended" do |s|
      s.gsub! " /var/log", " #{var}/log"
      s.gsub! " /opt/modsecurity/var", " #{opt_prefix}/var"
    end

    prefix.install "modsecurity.conf-recommended"
  end

  def caveats; <<-EOS.undent
    You must manually edit #{apache_configdir}/httpd.conf to include
      LoadModule security2_module #{libexec}/mod_security2.so

    You must also uncomment a line similar to the line below in #{apache_configdir}/httpd.conf to enable unique_id_module
      #LoadModule unique_id_module libexec/mod_unique_id.so

    Sample configuration file for Apache is at:
      #{prefix}/modsecurity.conf-recommended

    NOTE: If you're _NOT_ using --with-homebrew-httpd22 or --with-homebrew-httpd24 and having
    installation problems relating to a missing `cc` compiler and `OSX#{MacOS.version}.xctoolchain`,
    read the "Troubleshooting" section of https://github.com/Homebrew/homebrew-apache
    EOS
  end
end
