# OpenSSL 3.6+ enables CRL (Certificate Revocation List) checking by default.
# Most public CAs (including GitHub's) don't provide inline CRLs, causing
# "certificate verify failed (unable to get certificate CRL)" errors.
# This ensures a cert store with CRL checking disabled is set before
# SSLContext#set_params locks in verification parameters.
module OpenSSLNoCRL
  def set_params(params = {})
    unless cert_store
      self.cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store.flags = 0
    end
    super
  end
end

OpenSSL::SSL::SSLContext.prepend(OpenSSLNoCRL)
