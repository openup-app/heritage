import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:heritage/phone_input/countries.dart';
import 'package:heritage/phone_input/helpers.dart';

class CountryPickerContents extends StatefulWidget {
  final List<Country> countryList;
  final Country selectedCountry;
  final ValueChanged<Country> onCountryChanged;
  final String searchText;
  final List<Country> filteredCountries;
  final String languageCode;

  const CountryPickerContents({
    Key? key,
    required this.searchText,
    required this.languageCode,
    required this.countryList,
    required this.onCountryChanged,
    required this.selectedCountry,
    required this.filteredCountries,
  }) : super(key: key);

  @override
  State<CountryPickerContents> createState() => _CountryPickerContentsState();
}

class _CountryPickerContentsState extends State<CountryPickerContents> {
  late List<Country> _filteredCountries;

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.filteredCountries.toList()
      ..sort(
        (a, b) => a
            .localizedName(widget.languageCode)
            .compareTo(b.localizedName(widget.languageCode)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.search),
              labelText: widget.searchText,
            ),
            onChanged: (value) {
              final filteredCountries = widget.countryList.stringSearch(value)
                ..sort(
                  (a, b) => a
                      .localizedName(widget.languageCode)
                      .compareTo(b.localizedName(widget.languageCode)),
                );
              setState(() => _filteredCountries = filteredCountries);
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredCountries.length,
            separatorBuilder: (_, __) {
              return const Divider(
                thickness: 1,
                color: Color.fromRGBO(0xD8, 0xD8, 0xD8, 1.0),
              );
            },
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            itemBuilder: (_, index) {
              final country = _filteredCountries[index];
              return ListTile(
                leading: kIsWeb
                    ? Image.asset(
                        'assets/images/flags/${country.code.toLowerCase()}.png',
                        width: 32,
                      )
                    : Text(
                        _filteredCountries[index].flag,
                        style: const TextStyle(fontSize: 18),
                      ),
                title: Text(
                  _filteredCountries[index].localizedName(widget.languageCode),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Text(
                  '+${_filteredCountries[index].dialCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => widget.onCountryChanged(country),
              );
            },
          ),
        ),
      ],
    );
  }
}
