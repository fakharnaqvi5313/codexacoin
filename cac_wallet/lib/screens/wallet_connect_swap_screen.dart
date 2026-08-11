/// Connects to the user's own external wallet (MetaMask, Trust Wallet,
/// etc.) via WalletConnect/Reown AppKit and drives a PancakeSwap CAC<->USDT
/// swap through it. This wallet never holds a BSC private key and never
/// signs anything here -- every transaction is approved and signed inside
/// the connected external wallet app. Added alongside (not instead of) the
/// simpler "Buy / Sell CAC (PancakeSwap)" external-link button on the home
/// screen; see PARAMETERS.md section 31 for why both exist.
library;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reown_appkit/reown_appkit.dart';

import '../services/pancake_swap.dart';

/// Public Reown Cloud project identifier -- safe to embed in source (it is
/// not a secret; it only identifies this app to the WalletConnect relay).
const _reownProjectId = '235183a4acfe373ab6f82a554eb65397';

const _bscPublicRpcUrl = 'https://bsc-dataseed.binance.org/';

enum _SwapDirection { usdtToCac, cacToUsdt }

extension on _SwapDirection {
  EthereumAddress get sellToken =>
      this == _SwapDirection.usdtToCac ? usdtTokenAddress : cacTokenAddress;
  EthereumAddress get buyToken =>
      this == _SwapDirection.usdtToCac ? cacTokenAddress : usdtTokenAddress;
  int get sellDecimals => this == _SwapDirection.usdtToCac ? usdtDecimals : cacDecimals;
  int get buyDecimals => this == _SwapDirection.usdtToCac ? cacDecimals : usdtDecimals;
  String get sellSymbol => this == _SwapDirection.usdtToCac ? 'USDT' : 'CAC';
  String get buySymbol => this == _SwapDirection.usdtToCac ? 'CAC' : 'USDT';
  List<EthereumAddress> get path => [sellToken, buyToken];
}

const _slippagePresetsBps = [50, 100, 300]; // 0.5%, 1%, 3%

class WalletConnectSwapScreen extends StatefulWidget {
  const WalletConnectSwapScreen({super.key});

  @override
  State<WalletConnectSwapScreen> createState() => _WalletConnectSwapScreenState();
}

class _WalletConnectSwapScreenState extends State<WalletConnectSwapScreen> {
  ReownAppKitModal? _appKitModal;
  bool _initializing = true;
  String? _initError;

  final _amountController = TextEditingController();
  _SwapDirection _direction = _SwapDirection.usdtToCac;
  int _slippageBps = 100;

  bool _quoting = false;
  String? _quoteError;
  BigInt? _quotedAmountIn;
  BigInt? _quotedAmountOut;
  BigInt? _quotedMinOut;

  bool _swapping = false;
  String? _swapStatus;
  String? _swapError;

  @override
  void initState() {
    super.initState();
    _initModal();
  }

  Future<void> _initModal() async {
    try {
      final modal = ReownAppKitModal(
        context: context,
        projectId: _reownProjectId,
        metadata: const PairingMetadata(
          name: 'CodexaCoin Wallet',
          description: 'CodexaCoin (CAC) light wallet',
          url: 'https://codexacoin.com',
          icons: ['https://codexacoin.com/assets/favicon-32.png'],
        ),
        requiredNamespaces: {
          'eip155': const RequiredNamespace(
            chains: ['eip155:56'],
            methods: MethodsConstants.requiredMethods,
            events: EventsConstants.requiredEvents,
          ),
        },
      );
      modal.addListener(_onModalChanged);
      await modal.init();
      if (!mounted) return;
      setState(() {
        _appKitModal = modal;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = 'Could not start WalletConnect: $e';
        _initializing = false;
      });
    }
  }

  void _onModalChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appKitModal?.removeListener(_onModalChanged);
    _appKitModal?.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _resetQuote() {
    _quotedAmountIn = null;
    _quotedAmountOut = null;
    _quotedMinOut = null;
    _quoteError = null;
  }

  Future<void> _getQuote() async {
    setState(() {
      _swapError = null;
      _swapStatus = null;
      _resetQuote();
    });
    final BigInt amountIn;
    try {
      amountIn = parseTokenAmount(_amountController.text, _direction.sellDecimals);
      if (amountIn == BigInt.zero) throw const FormatException('Amount must be greater than zero');
    } catch (e) {
      setState(() => _quoteError = 'Enter a valid amount: $e');
      return;
    }

    setState(() => _quoting = true);
    final client = Web3Client(_bscPublicRpcUrl, http.Client());
    try {
      final router = DeployedContract(
        ContractAbi('PancakeRouter', const [getAmountsOutFunction], const []),
        pancakeRouterAddress,
      );
      final result = await client.call(
        contract: router,
        function: getAmountsOutFunction,
        params: [amountIn, _direction.path],
      );
      final amounts = (result.single as List).cast<BigInt>();
      final amountOut = amounts.last;
      if (!mounted) return;
      setState(() {
        _quotedAmountIn = amountIn;
        _quotedAmountOut = amountOut;
        _quotedMinOut = applySlippage(amountOut, slippageBps: _slippageBps);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _quoteError = 'Could not fetch a live quote: $e');
    } finally {
      client.dispose();
      if (mounted) setState(() => _quoting = false);
    }
  }

  bool get _quoteMatchesCurrentInput {
    if (_quotedAmountIn == null) return false;
    try {
      return _quotedAmountIn == parseTokenAmount(_amountController.text, _direction.sellDecimals);
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmSwap() async {
    final modal = _appKitModal;
    final amountIn = _quotedAmountIn;
    final minOut = _quotedMinOut;
    if (modal == null || !modal.isConnected || amountIn == null || minOut == null) return;

    final namespace = ReownAppKitModalNetworks.getNamespaceForChainId(
      modal.selectedChain?.chainId ?? '56',
    );
    final addressHex = modal.session?.getAddress(namespace);
    final topic = modal.session?.topic;
    if (addressHex == null || topic == null) {
      setState(() => _swapError = 'No connected wallet session -- connect first.');
      return;
    }
    final userAddress = EthereumAddress.fromHex(addressHex);

    setState(() {
      _swapping = true;
      _swapError = null;
      _swapStatus = 'Approve the ${_direction.sellSymbol} spend in your wallet app...';
    });
    try {
      final approveData = buildApproveCalldata(spender: pancakeRouterAddress, amount: amountIn);
      await modal.request(
        topic: topic,
        chainId: '56',
        request: SessionRequestParams(
          method: MethodsConstants.ethSendTransaction,
          params: [
            {'from': userAddress.hex, 'to': _direction.sellToken.hex, 'data': approveData},
          ],
        ),
      );

      if (!mounted) return;
      setState(() => _swapStatus = 'Confirm the swap in your wallet app...');
      final swapData = buildSwapExactTokensForTokensCalldata(
        amountIn: amountIn,
        amountOutMin: minOut,
        path: _direction.path,
        recipient: userAddress,
        deadline: deadlineMinutesFromNow(20),
      );
      await modal.request(
        topic: topic,
        chainId: '56',
        request: SessionRequestParams(
          method: MethodsConstants.ethSendTransaction,
          params: [
            {'from': userAddress.hex, 'to': pancakeRouterAddress.hex, 'data': swapData},
          ],
        ),
      );

      if (!mounted) return;
      setState(() {
        _swapStatus = 'Swap submitted. Check your wallet app or BscScan for confirmation.';
        _resetQuote();
        _amountController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _swapStatus = null;
        _swapError = 'Swap failed or was rejected: $e';
      });
    } finally {
      if (mounted) setState(() => _swapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Wallet & Swap')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_initError!, style: const TextStyle(color: Colors.red)),
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final modal = _appKitModal!;
    final connected = modal.isConnected;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Connects to your own wallet app (MetaMask, Trust Wallet, etc.) '
          "over WalletConnect. This app never sees or holds your BSC keys "
          "-- it only asks your wallet app to approve and swap, and you "
          "confirm each step there. Two separate transactions are needed: "
          "an approval, then the swap itself. Thin liquidity; see the Risk "
          "Disclosure before trading.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Center(
          child: connected
              ? AppKitModalAccountButton(appKitModal: modal)
              : AppKitModalConnectButton(appKit: modal),
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('USDT -> CAC'),
                selected: _direction == _SwapDirection.usdtToCac,
                onSelected: (_) => setState(() {
                  _direction = _SwapDirection.usdtToCac;
                  _resetQuote();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('CAC -> USDT'),
                selected: _direction == _SwapDirection.cacToUsdt,
                onSelected: (_) => setState(() {
                  _direction = _SwapDirection.cacToUsdt;
                  _resetQuote();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${_direction.sellSymbol})',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(_resetQuote),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Slippage tolerance:'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _slippageBps,
              items: [
                for (final bps in _slippagePresetsBps)
                  DropdownMenuItem(value: bps, child: Text('${bps / 100}%')),
              ],
              onChanged: (bps) {
                if (bps == null) return;
                setState(() {
                  _slippageBps = bps;
                  _resetQuote();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _quoting ? null : _getQuote,
          child: Text(_quoting ? 'Fetching quote...' : 'Get quote'),
        ),
        if (_quoteError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_quoteError!, style: const TextStyle(color: Colors.red)),
          ),
        if (_quotedAmountOut != null && _quoteMatchesCurrentInput)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated: ${formatTokenAmount(_quotedAmountOut!, _direction.buyDecimals)} ${_direction.buySymbol}',
                    ),
                    Text(
                      'Minimum received (after ${_slippageBps / 100}% slippage): '
                      '${formatTokenAmount(_quotedMinOut!, _direction.buyDecimals)} ${_direction.buySymbol}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (!connected || !_quoteMatchesCurrentInput || _swapping) ? null : _confirmSwap,
          child: Text(_swapping ? 'Swapping...' : 'Confirm swap'),
        ),
        if (!connected)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Connect a wallet above first.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        if (_swapStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_swapStatus!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        if (_swapError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_swapError!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
