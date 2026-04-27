#The following example will cause scenarios tagged with @fast to fail if the execution takes longer than 0.5 second

#Around('@fast') do |scenario, block|
#  Timeout.timeout(0.5) do
#    block.call
#  end
#end

#Before do
  # Do something before each scenario.
#end

#Before do |scenario|
  # The +scenario+ argument is optional, but if you use it, you can get the title,
  # description, or name (title + description) of the scenario that is about to be
  # executed.
  Rails.logger.debug "Starting scenario: #{scenario.title}"
#end

#AfterStep do |scenario|
  # Do something after each step.
#end

#Before('@cucumis, @sativus') do
  # This will only run before scenarios tagged
  # with @cucumis OR @sativus.
#end

#Before('@cucumis', '~@sativus') do
  # This will only run before scenarios tagged
  # with @cucumis AND NOT @sativus.
#end

#Before('@cucumis, @sativus', '@aqua') do
  # This will only run before scenarios tagged
  # with (@cucumis OR @sativus) AND @aqua 
#end

#AfterStep('@cucumis', '@sativus') do
  # This will only run after steps within scenarios tagged
  # with @cucumis AND @sativus.
#end
