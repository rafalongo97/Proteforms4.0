import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart' show FileImage, ResizeImage;
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

import '../models/relatorio.dart';
import '../models/obra.dart';
import '../models/item_relatorio.dart';
import '../models/foto_relatorio.dart';
import '../models/configuracao.dart';
import '../models/responsavel_tecnico.dart';

class PdfService {
  static Future<File> generateRelatorioPdf({
    required Relatorio relatorio,
    required Obra obra,
    required List<FotoRelatorio> fotos,
    List<ItemRelatorio> itens = const [],
    required Configuracao? config,
    List<ResponsavelTecnico> technicalResponsaveis = const [],
  }) async {
    final pdf = pw.Document(
      title: '${relatorio.reportTitle ?? "Relatório"} - ${obra.name}',
      author: config?.name ?? 'Proteforms',
    );

    // Fontes Times New Roman (Padrão PDF)
    final font = pw.Font.times();
    final fontBold = pw.Font.timesBold();
    final fontItalic = pw.Font.timesItalic();

    // Carregar Logo
    pw.ImageProvider? logoImage;
    if (config?.logo != null && config!.logo!.isNotEmpty) {
      final logoFile = File(config!.logo!);
      if (await logoFile.exists()) {
        logoImage = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }

    // Carregar Assinatura Local
    pw.ImageProvider? localSignImage;
    if (relatorio.localResponsibleSignature != null && relatorio.localResponsibleSignature!.isNotEmpty) {
      final signFile = File(relatorio.localResponsibleSignature!);
      if (await signFile.exists()) {
        localSignImage = pw.MemoryImage(await signFile.readAsBytes());
      }
    }

    // Carregar Assinaturas Técnicas
    final Map<int, pw.ImageProvider> technicalSigns = {};
    for (var resp in technicalResponsaveis) {
      if (resp.signaturePath != null && resp.signaturePath!.isNotEmpty) {
        final f = File(resp.signaturePath!);
        if (await f.exists()) {
          technicalSigns[resp.id!] = pw.MemoryImage(await f.readAsBytes());
        }
      }
    }

    // Carregar Fotos e Orientação
    final Map<int, pw.ImageProvider> fotosCarregadas = {};
    final Map<int, bool> isLandscape = {};
    for (var foto in fotos) {
      if (foto.localPath.isNotEmpty) {
        final file = File(foto.localPath);
        if (file.existsSync()) {
          try {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            isLandscape[foto.id!] = frame.image.width > frame.image.height;

            final provider = pw.MemoryImage(bytes);
            if (foto.id != null) fotosCarregadas[foto.id!] = provider;
          } catch (_) {}
        }
      }
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(2 * PdfPageFormat.cm),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold, italic: fontItalic),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) {
          if (context.pageNumber == 1) return pw.SizedBox.shrink();
          return _buildFixedHeader(config, logoImage, relatorio, obra, fontBold);
        },
        footer: (context) => _buildFooter(context, config),
        build: (context) {
          int sectionIndex = 1;
          return [
            // PÁGINA 1: CAPA
            _buildCapa(config, logoImage, relatorio, obra, fontBold),
            pw.NewPage(),

            // PÁGINA 2: IDENTIFICAÇÃO
            // PÁGINA 2: IDENTIFICAÇÃO
            _buildSectionTitle('${sectionIndex++}. IDENTIFICAÇÃO', fontBold),
            _buildEmpresaBox(config, fontBold),
            pw.SizedBox(height: 15),
            _buildObraBox(obra, relatorio, fontBold),
            pw.SizedBox(height: 15),
            _buildTecnicosBox(technicalResponsaveis, fontBold),
            pw.SizedBox(height: 20),

            // PÁGINA 3+: CONTEÚDO
            if (relatorio.introduction != null && relatorio.introduction!.isNotEmpty) ...[
              _buildSectionTitle('${sectionIndex++}. INTRODUÇÃO', fontBold),
              pw.Paragraph(text: relatorio.introduction!, textAlign: pw.TextAlign.justify),
              pw.SizedBox(height: 15),
            ],

            if (itens.isNotEmpty) ...[
              _buildSectionTitle('${sectionIndex++}. CHECKLIST DE INSPEÇÃO', fontBold),
              _buildChecklistTable(itens, fontBold),
              pw.SizedBox(height: 20),
            ],

            if (relatorio.technicalObservations != null && relatorio.technicalObservations!.isNotEmpty) ...[
              _buildSectionTitle('${sectionIndex++}. OBSERVAÇÕES TÉCNICAS', fontBold),
              pw.Paragraph(text: relatorio.technicalObservations!, textAlign: pw.TextAlign.justify),
              pw.SizedBox(height: 20),
            ],

            if (fotos.isNotEmpty || relatorio.id == 0) ...[
              _buildSectionTitle('${sectionIndex++}. REGISTROS FOTOGRÁFICOS', fontBold),
              if (fotos.isNotEmpty) ..._buildFotosGrid(fotos, fotosCarregadas, isLandscape),
              if (fotos.isEmpty && relatorio.id == 0) 
                 pw.Paragraph(text: 'As fotos inseridas no relatório aparecerão nesta seção, organizadas em grade com suas respectivas legendas.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 20),
            ],

            if (relatorio.finalDeclaration != null && relatorio.finalDeclaration!.isNotEmpty) ...[
              _buildSectionTitle('${sectionIndex++}. DECLARAÇÃO FINAL', fontBold),
              pw.Paragraph(text: relatorio.finalDeclaration!, textAlign: pw.TextAlign.justify),
              pw.SizedBox(height: 30),
            ],

            // DATA E LOCAL
            // DATA E LOCAL
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                _formatLongDate(relatorio.inspectionDate, config?.city, config?.state),
                style: pw.TextStyle(fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 40),

            // ASSINATURAS
            _buildAssinaturas(technicalResponsaveis, technicalSigns, relatorio, localSignImage, fontBold),
          ];
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File('${outputDir.path}/relatorio_${relatorio.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static String _formatLongDate(String? dateStr, String? city, String? state) {
    if (dateStr == null || dateStr.isEmpty) return '${city ?? "Cidade"}, ${state ?? "UF"}';
    try {
      DateTime date = DateFormat('dd/MM/yyyy').parse(dateStr);
      String longDate = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(date);
      return '${city ?? "Cidade"}, ${state ?? "UF"}, $longDate';
    } catch (e) {
      return '${city ?? "Cidade"}, ${state ?? "UF"}, $dateStr';
    }
  }

  static pw.Widget _buildCapa(Configuracao? config, pw.ImageProvider? logo, Relatorio relatorio, Obra obra, pw.Font bold) {
    return pw.Container(
      height: 700,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (logo != null)
            pw.Center(child: pw.Image(logo, width: 200, height: 200, fit: pw.BoxFit.contain))
          else
            pw.SizedBox(height: 150),
          
          pw.Column(
            children: [
              pw.Text(
                (relatorio.reportTitle ?? 'RELATÓRIO DE INSPEÇÃO').toUpperCase(),
                style: pw.TextStyle(font: bold, fontSize: 24),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                obra.name.toUpperCase(),
                style: pw.TextStyle(font: bold, fontSize: 20, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              if (obra.contractor != null && obra.contractor!.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  obra.contractor!.toUpperCase(),
                  style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ],
          ),

          pw.Column(
            children: [
              pw.Text(config?.name ?? '', style: pw.TextStyle(fontSize: 14)),
              pw.Text('${config?.city ?? "Cidade"} - ${config?.state ?? "UF"}', style: pw.TextStyle(fontSize: 12)),
              pw.Text(relatorio.inspectionDate ?? '', style: pw.TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFixedHeader(Configuracao? config, pw.ImageProvider? logo, Relatorio relatorio, Obra obra, pw.Font bold) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null)
              pw.Image(logo, width: 50, height: 50, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(width: 50),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(relatorio.reportTitle?.toUpperCase() ?? 'RELATÓRIO', style: pw.TextStyle(font: bold, fontSize: 10)),
                  pw.Text('Obra: ${obra.name}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Relatório: ${relatorio.reportNumber ?? ""}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Data: ${relatorio.inspectionDate ?? ""}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, Configuracao? config) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(config?.name ?? 'Proteforms', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 14)),
    );
  }

  static pw.Widget _buildEmpresaBox(Configuracao? config, pw.Font bold) {
    return _buildBorderBox(
      'Dados da Empresa',
      bold,
      [
        'Razão Social: ${config?.name ?? ""}',
        'CNPJ: ${config?.cnpj ?? ""}',
        'Endereço: ${config?.address ?? ""}',
        'Cidade/UF: ${config?.city ?? ""} - ${config?.state ?? ""}',
      ],
    );
  }

  static pw.Widget _buildObraBox(Obra obra, Relatorio relatorio, pw.Font bold) {
    return _buildBorderBox(
      'Dados da Unidade / Obra',
      bold,
      [
        'Nome da Obra: ${obra.name}',
        'Endereço: ${obra.address ?? ""}',
        'Contratante: ${obra.contractor ?? ""}',
        'Contrato: ${obra.contractNumber ?? ""}',
        'Responsável Local: ${relatorio.localResponsibleName ?? obra.responsible ?? ""}',
      ],
    );
  }

  static pw.Widget _buildTecnicosBox(List<ResponsavelTecnico> resps, pw.Font bold) {
    List<String> lines = [];
    for (int i = 0; i < resps.length; i++) {
      final r = resps[i];
      lines.add('Responsável ${i + 1}: ${r.name} - ${r.title} (${r.docType}: ${r.regNumber})');
    }
    return _buildBorderBox('Responsáveis Técnicos', bold, lines);
  }

  static pw.Widget _buildBorderBox(String title, pw.Font bold, List<String> lines) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(), style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.SizedBox(height: 5),
          ...lines.map((l) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Text(l, style: const pw.TextStyle(fontSize: 9)))),
        ],
      ),
    );
  }

  static pw.Widget _buildChecklistTable(List<ItemRelatorio> itens, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FixedColumnWidth(80)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Inspecionado', style: pw.TextStyle(font: bold, fontSize: 10))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Status', style: pw.TextStyle(font: bold, fontSize: 10), textAlign: pw.TextAlign.center)),
              ],
            ),
            ...itens.map((item) => pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 10))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    item.status ?? '-', 
                    textAlign: pw.TextAlign.center, 
                    style: pw.TextStyle(
                      font: bold, 
                      fontSize: 10, 
                      color: item.status == 'NC' ? PdfColors.red : (item.status == 'C' ? PdfColors.green : PdfColors.grey700)
                    )
                  ),
                ),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Legenda: C = Conforme; NC = Não Conforme; NA = Não Aplica',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildFotosGrid(List<FotoRelatorio> fotos, Map<int, pw.ImageProvider> fotosCarregadas, Map<int, bool> isLandscape) {
    List<pw.Widget> result = [];
    for (int i = 0; i < fotos.length; i += 2) {
      final foto1 = fotos[i];
      final img1 = fotosCarregadas[foto1.id];

      final hasSecond = i + 1 < fotos.length;
      final foto2 = hasSecond ? fotos[i + 1] : null;
      final img2 = foto2 != null ? fotosCarregadas[foto2.id] : null;

      result.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (img1 != null) 
              _buildFotoItem(img1, foto1.caption),
            
            pw.SizedBox(width: 10),
            
            if (img2 != null) 
              _buildFotoItem(img2, foto2!.caption)
            else
               pw.Expanded(flex: 1, child: pw.SizedBox()), // Garante que a primeira não estique se for única
          ],
        ),
      );
      result.add(pw.SizedBox(height: 10));
    }
    return result;
  }

  static pw.Widget _buildFotoItem(pw.ImageProvider img, String? caption) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Container(
            height: 230, // Aumentado para preencher melhor a largura da página em 2 colunas
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Image(img, fit: pw.BoxFit.fill), // "Esticada" para ser quadrada completa
          ),
          pw.SizedBox(height: 5),
          pw.Text(caption ?? '', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _buildAssinaturas(List<ResponsavelTecnico> resps, Map<int, pw.ImageProvider> signs, Relatorio relatorio, pw.ImageProvider? localSign, pw.Font bold) {
    return pw.Column(
      children: [
        // Responsáveis Técnicos (Lado a Lado)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: resps.map((r) => _buildSignatureBlock(
            r.name ?? '', 
            r.title ?? '', 
            '${r.docType}: ${r.regNumber}', 
            signs[r.id], 
            bold
          )).toList(),
        ),
        
        pw.SizedBox(height: 30),

        // Responsável Local (Sempre Abaixo)
        pw.Center(
          child: _buildSignatureBlock(
            relatorio.localResponsibleName ?? 'Responsável Local', 
            'Responsável do Local', 
            '', 
            localSign, 
            bold
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureBlock(String name, String title, String reg, pw.ImageProvider? sign, pw.Font bold) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (sign != null)
          pw.Image(sign, width: 100, height: 50, fit: pw.BoxFit.contain)
        else
          pw.SizedBox(height: 50, width: 100),
        pw.Container(width: 150, child: pw.Divider(thickness: 0.5)),
        pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 9)),
        pw.Text(title, style: const pw.TextStyle(fontSize: 8)),
        if (reg.isNotEmpty) pw.Text(reg, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
