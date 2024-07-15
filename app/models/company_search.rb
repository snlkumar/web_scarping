class CompanySearch
  include ActiveModel::Model
  attr_accessor :limit, :batch, :industry, :region, :tag, :company_size, :is_hiring, :nonprofit, :black_founded, :women_founded
end