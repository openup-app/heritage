import 'package:flutter/material.dart';
import 'package:heritage/phone_input/countries.dart';
import 'package:heritage/phone_input/country_picker_dialog.dart';
import 'package:heritage/phone_input/intl_phone_field.dart';
import 'package:heritage/phone_input/phone_number.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class PhoneInput extends StatefulWidget {
  final String? initialPhoneNumber;
  final void Function(PhoneNumber phoneNumber) onChanged;

  const PhoneInput({
    super.key,
    this.initialPhoneNumber,
    required this.onChanged,
  });

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  final _textController = TextEditingController();
  Country _selectedCountry =
      countries.firstWhere((e) => e.name == 'United States');

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      controller: _textController,
      initialValue: widget.initialPhoneNumber,
      country: _selectedCountry,
      keyboardType: TextInputType.number,
      disableLengthCheck: true,
      decoration: const InputDecoration(
        hintText: 'Phone number',
      ),
      onChanged: widget.onChanged,
      onPickCountry: _showCountryPicker,
    );
  }

  Future<void> _showCountryPicker() async {
    const countriesList = countries;
    final country = await showModalBottomSheet<Country>(
      context: context,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      builder: (context) {
        return PointerInterceptor(
          child: Material(
            type: MaterialType.transparency,
            child: CountryPickerContents(
              languageCode: 'en',
              filteredCountries: countriesList,
              searchText: '',
              countryList: countries,
              selectedCountry: _selectedCountry,
              onCountryChanged: (country) => Navigator.of(context).pop(country),
            ),
          ),
        );
      },
    );
    if (mounted && country != null) {
      setState(() => _selectedCountry = country);
    }
    final number = PhoneNumber(
      countryISOCode: _selectedCountry.code,
      countryCode:
          '+${_selectedCountry.dialCode}${_selectedCountry.regionCode}',
      number: _textController.text,
    );
    widget.onChanged(number);
  }
}
