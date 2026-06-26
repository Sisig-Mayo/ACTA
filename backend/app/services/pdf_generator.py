"""
ACTA Backend — PDF Blueprint Engine
=====================================
Synthesizes simulation outputs, resource allocations, and
spatial risk assessments into a downloadable offline-ready
Master Action Plan PDF for administrative sign-off.

Target Branch : feature/backend-decay
Commit        : feat(backend): implement pdf blueprint engine for master action plans
"""

from __future__ import annotations

import logging
from datetime import datetime
from io import BytesIO

from app.models.simulation import SimulationOutput, TaskItem

logger = logging.getLogger("acta.pdf_generator")

try:
    from fpdf import FPDF
except ImportError:
    FPDF = None


class ActaPDF(FPDF):
    """Custom PDF class with ACTA headers and footers."""
    
    def header(self):
        self.set_font("helvetica", "B", 15)
        # Title
        self.cell(0, 10, "ACTA: Master Action Plan Blueprint", border=0, ln=1, align="C")
        self.set_font("helvetica", "I", 10)
        self.cell(0, 8, "Context-Aware Decision-to-Action Simulation Engine", border=0, ln=1, align="C")
        self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font("helvetica", "I", 8)
        self.set_text_color(128)
        # Page number
        self.cell(0, 10, f"Page {self.page_no()}", align="C")


def generate_master_action_plan(simulation: SimulationOutput) -> bytes:
    """
    Generate the Master Action Plan PDF blueprint.
    
    Contains:
    - Executive Incident Summary
    - Risk Matrix (Barangay Impacts)
    - Time-Decayed Task Ledger
    """
    if FPDF is None:
        logger.error("fpdf2 library is not installed.")
        raise RuntimeError("PDF generation requires 'fpdf2' package.")

    pdf = ActaPDF()
    pdf.add_page()

    # 1. Executive Incident Summary
    pdf.set_font("helvetica", "B", 14)
    pdf.set_fill_color(240, 240, 240)
    pdf.cell(0, 10, " 1. Executive Incident Summary", ln=1, fill=True)
    pdf.ln(2)

    pdf.set_font("helvetica", "", 11)
    
    summary_text = (
        f"Generated At: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"Severity Tier: {simulation.severity_tier.name.upper()}\n"
        f"Preparation Window: {simulation.preparation_window_hours} hours\n\n"
        f"AI Context Summary:\n{simulation.explainability_card.summary}"
    )
    pdf.multi_cell(0, 6, summary_text)
    pdf.ln(5)

    # 2. Risk Overview
    pdf.set_font("helvetica", "B", 14)
    pdf.cell(0, 10, " 2. Asset & Risk Overview", ln=1, fill=True)
    pdf.ln(2)
    
    red_zones = simulation.metadata.get("red_zone_count", 0)
    yellow_zones = simulation.metadata.get("yellow_zone_count", 0)

    pdf.set_font("helvetica", "", 11)
    pdf.cell(0, 6, f"Total Impacted Barangays: {len(simulation.impacted_barangays)}", ln=1)
    pdf.cell(0, 6, f"Critical RED Zones: {red_zones}", ln=1)
    pdf.cell(0, 6, f"Elevated YELLOW Zones: {yellow_zones}", ln=1)
    pdf.ln(5)

    # 3. Task Ledger
    pdf.set_font("helvetica", "B", 14)
    pdf.cell(0, 10, " 3. Time-Decayed Task Ledger", ln=1, fill=True)
    pdf.ln(2)

    # Task Blocks
    for i, task in enumerate(simulation.task_list, 1):
        pdf.set_font("helvetica", "B", 10)
        cat_formatted = " ".join([w.capitalize() for w in task.category.split('_')])
        
        # Highlight Critical tasks in red, others in black
        if task.priority.upper() == "CRITICAL":
            pdf.set_text_color(220, 38, 38)
        elif task.priority.upper() == "HIGH":
            pdf.set_text_color(234, 88, 12)
        else:
            pdf.set_text_color(0, 0, 0)
            
        pdf.cell(0, 6, f"{i}. [T-{task.deadline_hours}h] {task.priority} Priority | {cat_formatted}", ln=1)
        
        # Reset text color for action
        pdf.set_text_color(0, 0, 0)
        pdf.set_font("helvetica", "", 10)
        
        # MultiCell allows the long text to wrap to the next line naturally
        pdf.multi_cell(0, 6, f"Directive: {task.action}")
        pdf.ln(4)
        
    pdf.ln(5)

    # 4. Sign-off Section
    pdf.set_font("helvetica", "B", 12)
    pdf.cell(0, 10, "Authorization Sign-off", ln=1)
    pdf.ln(10)
    pdf.cell(90, 8, "________________________________________", ln=0)
    pdf.cell(90, 8, "________________________________________", ln=1)
    pdf.set_font("helvetica", "", 10)
    pdf.cell(90, 6, "LGU Operations Commander", ln=0)
    pdf.cell(90, 6, "Date & Time", ln=1)

    # Generate PDF to byte array
    return pdf.output(dest='S')
