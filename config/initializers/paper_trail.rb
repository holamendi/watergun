PaperTrail.serializer = PaperTrail::Serializers::JSON
PaperTrail.config.has_paper_trail_defaults = {
  ignore: %i[updated_at]
}
