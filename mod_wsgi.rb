class ModWsgi < Formula
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

  desc "Host Python web apps supporting the Python WSGI spec"
  homepage "http://modwsgi.readthedocs.org/en/latest/"
  url "https://github.com/GrahamDumpleton/mod_wsgi/archive/4.5.14.tar.gz"
  sha256 "18a0a879d1130116b5fd0253d2d0695fe2c40db6f09b82a8fcb29bcb8c2fa989"
  head "https://github.com/GrahamDumpleton/mod_wsgi.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "ac3273f6757cca4f5b2047ba6e1395c3a42380dd057d02df0875712d9e3dd80a" => :el_capitan
    sha256 "993c41e044fae6635a26c5bc809fdb388f10afb60c7ff2f8f18cd0bb5e1dcb1f" => :yosemite
    sha256 "f5eefa629ac36cd490600b2d833cc7eae111ecd2506ed1f4b11031bb320aec80" => :mavericks
  end

  option "with-httpd22", "Use Homebrew Apache httpd 2.2"
  option "with-httpd24", "Use Homebrew Apache httpd 2.4"
  option "with-python", "Use Homebrew python"

  deprecated_option "with-homebrew-httpd22" => "with-httpd22"
  deprecated_option "with-homebrew-httpd24" => "with-httpd24"
  deprecated_option "with-homebrew-python" => "with-python"
  deprecated_option "with-brewed-httpd22" => "with-httpd22"
  deprecated_option "with-brewed-httpd24" => "with-httpd24"
  deprecated_option "with-brewed-python" => "with-python"

  depends_on "httpd22" => :optional
  depends_on "httpd24" => :optional
  depends_on "python" => :optional
  if MacOS.version < :sierra && build.without?("httpd22") && build.without?("httpd24")
    depends_on CLTRequirement
  elsif MacOS.version >= :sierra && build.without?("httpd22") && build.without?("httpd24")
    depends_on "apr"
    depends_on "apr-util"
  end

  def apache_apxs
    if build.with? "httpd22"
      %W[sbin bin].each do |dir|
        if File.exist?(location = "#{Formula["httpd22"].opt_prefix}/#{dir}/apxs")
          return location
        end
      end
    elsif build.with? "httpd24"
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
    if build.with? "httpd22"
      "#{etc}/apache2/2.2"
    elsif build.with? "httpd24"
      "#{etc}/apache2/2.4"
    else
      "/etc/apache2"
    end
  end

  def install
    if build.with?("httpd22") && build.with?("httpd24")
      odie "Cannot build for http22 and httpd24 at the same time"
    end

    apxs = apache_apxs

    if MacOS.version >= :sierra && build.without?("httpd22") && build.without?("httpd24")
      cp "/usr/sbin/apxs", "brew-apxs" # build system outputs "apxs"
      inreplace "brew-apxs" do |s|
        s.gsub! "my $installbuilddir = \"/usr/share/httpd/build\";",
                "my $installbuilddir = \"#{buildpath}\";"
        s.gsub! "$installbuilddir/instdso.sh", "/usr/share/httpd/build/instdso.sh"
      end

      cp "/usr/share/httpd/build/config_vars.mk", buildpath
      inreplace "config_vars.mk" do |s|
        developer = "/Applications/Xcode.app/Contents/Developer"
        internal_sdk = "#{developer}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX#{MacOS.version}.Internal.sdk"
        xctoolchain = "#{developer}/Toolchains/OSX#{MacOS.version}.xctoolchain"

        # EXTRA_CPPFLAGS and EXTRA_INCLUDES
        s.gsub! "-I#{internal_sdk}/usr/include/apr-1",
                "-I#{Formula["apr"].opt_libexec}/include/apr-1"

        s.gsub! "#{xctoolchain}/usr/local/share/apr-1/build-1/libtool",
                "#{Formula["apr"].opt_libexec}/build-1/libtool"

        s.gsub! "APR_BINDIR = #{xctoolchain}/usr/local/bin",
                "APR_BINDIR = #{Formula["apr"].opt_bin}"
        s.gsub! "APR_INCLUDEDIR = #{internal_sdk}/usr/include/apr-1",
                "APR_INCLUDEDIR = #{Formula["apr"].opt_libexec}/include/apr-1"

        s.gsub! "APR_CONFIG = #{xctoolchain}/usr/local/bin/apr-1-config",
                "APR_CONFIG = #{Formula["apr"].opt_bin}/apr-1-config"

        s.gsub! "APU_BINDIR = #{xctoolchain}/usr/local/bin",
                "APU_BINDIR = #{Formula["apr-util"].opt_bin}"

        s.gsub! "APU_INCLUDEDIR = #{internal_sdk}/usr/include/apr-1",
                "APU_INCLUDEDIR = #{Formula["apr-util"].opt_libexec}/include/apr-1"

        s.gsub! "APU_CONFIG = #{xctoolchain}/usr/local/bin/apu-1-config",
                "APU_CONFIG = #{Formula["apr-util"].opt_bin}/apu-1-config"
      end
      cp (MacOS.sdk.path/"usr/include/apache2").children, "src/server"
      apxs = buildpath/"brew-apxs"
    end

    args = %W[
      --prefix=#{prefix}
      --disable-framework
      --with-apxs=#{apxs}
    ]
    if build.with? "python"
      args << "--with-python=#{Formula["python"].opt_bin}/python"
    end
    system "./configure", *args
    system "make", "LIBEXECDIR=#{libexec}", "install"

    pkgshare.install "tests"
  end

  def caveats; <<-EOS.undent
    You must manually edit #{apache_configdir}/httpd.conf to include
      LoadModule wsgi_module #{libexec}/mod_wsgi.so

    NOTE: If you're _NOT_ using --with-httpd22 or --with-httpd24 and having
    installation problems relating to a missing `cc` compiler and `OSX#{MacOS.version}.xctoolchain`,
    read the "Troubleshooting" section of https://github.com/Homebrew/homebrew-apache
    EOS
  end
end
