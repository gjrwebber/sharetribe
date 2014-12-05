class CommunityDomain
  def self.matches?(request)
    ! APP_CONFIG.domain.include?(request.domain)
  end
end
