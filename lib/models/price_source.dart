enum PriceSource { live, recorded, screenshot }

extension PriceSourceLabel on PriceSource {
  String get label => switch (this) {
        PriceSource.live => 'Live',
        PriceSource.recorded => 'Recorded',
        PriceSource.screenshot => 'Screenshot',
      };
}
