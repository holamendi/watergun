module FormsHelper
  def error_messages_for(object, attribute)
    error_messages(object.errors.messages_for(attribute))
  end

  def error_messages(messages)
    return unless messages.any?

    tag.div(class: "label") do
      safe_join(
        messages.map do |message|
          tag.span(message, class: "label-text-alt text-error")
        end
      )
    end
  end
end
