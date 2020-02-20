module SearchHelpers
  def search_for(query)
    visit '/'
    fill_in 'home_q', with: query
    click_button 'Search'
  end
end
