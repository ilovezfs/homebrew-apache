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
  url "https://github.com/GrahamDumpleton/mod_wsgi/archive/4.5.7.tar.gz"
  sha256 "8d84a7bc6983c776ca50ba8183b450cc6f75fd8cca8ae0bc9a582073f8e4eeec"
  head "https://github.com/GrahamDumpleton/mod_wsgi.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "13530839dc2c918d62c9e6d1003a0b01cb6e5975dd70b26cf10b8b0d8ce0a92a" => :el_capitan
    sha256 "94ceae5a9764a53c096359fb128cd560b09806b9ce52cdede4b20f14057663e4" => :yosemite
    sha256 "9031d1bab170f5ec258c75f61267402ae9c8fce413ee2d7acea80eeb05e0c8b7" => :mavericks
  end

  option "with-homebrew-httpd22", "Use Homebrew Apache httpd 2.2"
  option "with-homebrew-httpd24", "Use Homebrew Apache httpd 2.4"
  option "with-homebrew-python", "Use Homebrew python"

  deprecated_option "with-brewed-httpd22" => "with-homebrew-httpd22"
  deprecated_option "with-brewed-httpd24" => "with-homebrew-httpd24"
  deprecated_option "with-brewed-python" => "with-homebrew-python"

  depends_on "httpd22" if build.with? "homebrew-httpd22"
  depends_on "httpd24" if build.with? "homebrew-httpd24"
  depends_on "python" if build.with? "homebrew-python"
  depends_on CLTRequirement if build.without?("homebrew-httpd22") && build.without?("homebrew-httpd24")

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
      --disable-framework
      --with-apxs=#{apache_apxs}
    ]

    args << "--with-python=#{HOMEBREW_PREFIX}/bin/python" if build.with? "homebrew-python"
    system "./configure", *args
    system "make", "LIBEXECDIR=#{libexec}", "install"

    pkgshare.install "tests"
    doc.install "README.rst"
  end

  def caveats; <<-EOS.undent
    You must manually edit #{apache_configdir}/httpd.conf to include
      LoadModule wsgi_module #{libexec}/mod_wsgi.so

    NOTE: If you're _NOT_ using --with-homebrew-httpd22 or --with-homebrew-httpd24 and having
    installation problems relating to a missing `cc` compiler and `OSX#{MacOS.version}.xctoolchain`,
    read the "Troubleshooting" section of https://github.com/Homebrew/homebrew-apache
    EOS
  end
end
